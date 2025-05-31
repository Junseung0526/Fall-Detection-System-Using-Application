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

  /// 외부에서 연결 여부를 확인할 수 있도록 추가
  bool get isConnected => connectedDevice != null;
  bool get isReady => notifyCharacteristic != null;

  Future<bool> scanAndConnect() async {
    print("🔍 BLE 스캔 시작...");
    bool connected = false;

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

    try {
      await for (final scanResultList in FlutterBluePlus.scanResults) {
        for (final r in scanResultList) {
          print("📡 발견된 기기: '${r.device.name}' / ID: ${r.device.remoteId}");

          final hasTargetService = r.advertisementData.serviceUuids.any(
                (uuid) => uuid.toString().toLowerCase() == serviceUuid.toString().toLowerCase(),
          );

          if (hasTargetService) {
            await FlutterBluePlus.stopScan();

            connectedDevice = r.device;

            // 연결 전에 중복 연결 방지
            if (connectedDevice!.isConnected == false) {
              await connectedDevice!.connect(timeout: const Duration(seconds: 5));
            }

            // 서비스 탐색 및 characteristic 설정
            List<BluetoothService> services = await connectedDevice!.discoverServices();

            for (var service in services) {
              if (service.uuid == serviceUuid) {
                for (var characteristic in service.characteristics) {
                  if (characteristic.uuid == writeCharUuid) {
                    writeCharacteristic = characteristic;
                  }

                  if (characteristic.uuid == notifyCharUuid) {
                    notifyCharacteristic = characteristic;

                    // 알림 설정
                    await notifyCharacteristic!.setNotifyValue(true);
                  }
                }
              }
            }

            // notifyCharacteristic가 반드시 설정되었는지 확인
            if (notifyCharacteristic != null) {
              connected = true;
              print("✅ BLE 연결 및 notify 설정 완료");
            } else {
              print("⚠️ notifyCharacteristic 설정 실패");
              await disconnect();
            }

            break;
          }
        }

        if (connected) break;
      }
    } catch (e) {
      print("❌ BLE 연결 오류: $e");
      await disconnect(); // 실패 시 상태 초기화
    }

    return connected;
  }

  Stream<List<int>>? get notifyStream {
    return notifyCharacteristic?.lastValueStream;
  }

  Future<void> write(String data) async {
    if (writeCharacteristic != null) {
      await writeCharacteristic!.write(data.codeUnits);
    }
  }

  Future<void> disconnect() async {
    print("🔌 BLE 연결 해제 시도");
    try {
      await connectedDevice?.disconnect();
    } catch (_) {}

    connectedDevice = null;
    writeCharacteristic = null;
    notifyCharacteristic = null;
  }
}
