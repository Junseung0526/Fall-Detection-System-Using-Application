import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleManager {
  // 싱글톤 인스턴스
  static final BleManager instance = BleManager._internal();
  BleManager._internal();
  factory BleManager() => instance;

  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? writeCharacteristic;
  BluetoothCharacteristic? notifyCharacteristic;

  final Guid serviceUuid = Guid("0000FFE0-0000-1000-8000-00805F9B34FB");
  final Guid writeCharUuid = Guid("0000FFE1-0000-1000-8000-00805F9B34FB");
  final Guid notifyCharUuid = Guid("0000FFE1-0000-1000-8000-00805F9B34FB");

  Future<bool> scanAndConnect() async {
    bool connected = false;

    print("🔍 BLE 스캔 시작...");
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

    try {
      await for (final scanResultList in FlutterBluePlus.scanResults) {
        for (final r in scanResultList) {
          print("📡 발견된 기기: '${r.device.name}' / ID: ${r.device.remoteId}");

          if (r.advertisementData.serviceUuids.any((uuid) => uuid.toString().toLowerCase() == serviceUuid.toString().toLowerCase())) {
            await FlutterBluePlus.stopScan();

            connectedDevice = r.device;
            await connectedDevice!.connect();

            List<BluetoothService> services = await connectedDevice!.discoverServices();
            for (var service in services) {
              if (service.uuid == serviceUuid) {
                for (var characteristic in service.characteristics) {
                  if (characteristic.uuid == writeCharUuid) {
                    writeCharacteristic = characteristic;
                  } else if (characteristic.uuid == notifyCharUuid) {
                    notifyCharacteristic = characteristic;
                    await notifyCharacteristic!.setNotifyValue(true);
                  }
                }
              }
            }

            connected = true;
            break;
          }
        }
        if (connected) break;
      }
    } catch (e) {
      print("❌ BLE 연결 오류: $e");
    }

    return connected;
  }

  Stream<List<int>>? get notifyStream {
    if (notifyCharacteristic == null) return null;
    return notifyCharacteristic!.lastValueStream;
  }

  Future<void> write(String data) async {
    if (writeCharacteristic != null) {
      await writeCharacteristic!.write(data.codeUnits);
    }
  }

  Future<void> disconnect() async {
    if (connectedDevice != null) {
      await connectedDevice!.disconnect();
      connectedDevice = null;
      writeCharacteristic = null;
      notifyCharacteristic = null;
    }
  }
}
