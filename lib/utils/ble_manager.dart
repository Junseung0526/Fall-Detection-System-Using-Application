import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleManager {
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? writeCharacteristic;
  BluetoothCharacteristic? notifyCharacteristic;

  // ESP32 예시 UUID (수정 필요 시 여기만 변경)
  final Guid serviceUuid = Guid("0000FFE0-0000-1000-8000-00805F9B34FB");
  final Guid writeCharUuid = Guid("0000FFE1-0000-1000-8000-00805F9B34FB");
  final Guid notifyCharUuid = Guid("0000FFE1-0000-1000-8000-00805F9B34FB");

  Future<bool> scanAndConnect(String targetDeviceName) async {
    bool connected = false;

    // 스캔 시작
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

    try {
      await for (var scanResultList in FlutterBluePlus.scanResults) {
        for (var r in scanResultList) {
          if (r.device.name == targetDeviceName) {
            // 기기 발견 시 스캔 중지
            await FlutterBluePlus.stopScan();

            try {
              // 기기 연결 시도
              await r.device.connect(timeout: const Duration(seconds: 10));
              connectedDevice = r.device;

              // 서비스 탐색
              List<BluetoothService> services = await connectedDevice!.discoverServices();

              // 서비스 및 특성 찾기
              for (var service in services) {
                if (service.uuid == serviceUuid) {
                  for (var c in service.characteristics) {
                    if (c.uuid == writeCharUuid) {
                      writeCharacteristic = c;
                    }
                    if (c.uuid == notifyCharUuid) {
                      notifyCharacteristic = c;
                      // Notify 활성화
                      await notifyCharacteristic!.setNotifyValue(true);
                    }
                  }
                }
              }

              // writeCharacteristic과 notifyCharacteristic이 모두 있어야 연결 성공으로 간주
              connected = writeCharacteristic != null && notifyCharacteristic != null;
            } catch (e) {
              print('기기 연결 또는 서비스 탐색 실패: $e');
              connected = false;
            }
            break;
          }
        }
        if (connected) break;
      }
    } catch (e) {
      print('스캔 중 오류 발생: $e');
    } finally {
      // 혹시 스캔이 아직 켜져 있으면 종료
      await FlutterBluePlus.stopScan();
    }

    return connected;
  }

  Future<void> disconnect() async {
    if (connectedDevice != null) {
      try {
        await connectedDevice!.disconnect();
      } catch (e) {
        print('기기 연결 해제 실패: $e');
      }
      connectedDevice = null;
      writeCharacteristic = null;
      notifyCharacteristic = null;
    }
  }

  Future<bool> writeData(List<int> data) async {
    if (writeCharacteristic == null) {
      print('Write 특성이 없습니다.');
      return false;
    }

    try {
      // withoutResponse 옵션 필요시 true로 변경 가능
      await writeCharacteristic!.write(data, withoutResponse: false);
      return true;
    } catch (e) {
      print('데이터 쓰기 실패: $e');
      return false;
    }
  }

  Stream<List<int>>? get notifyStream {
    if (notifyCharacteristic == null) return null;
    return notifyCharacteristic!.value;
  }
}
