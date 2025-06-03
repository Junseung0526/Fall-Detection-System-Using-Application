import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'alert_helper.dart'; // 경로에 맞게 조정하세요

class BleManager {
  static final BleManager _instance = BleManager._internal();
  factory BleManager() => _instance;
  BleManager._internal();

  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? writeCharacteristic;
  BluetoothCharacteristic? notifyCharacteristic;

  final Guid serviceUuid = Guid("0000FFE0-0000-1000-8000-00805F9B34FB");
  final Guid writeCharUuid = Guid("0000FFE1-0000-1000-8000-00805F9B34FB");
  final Guid notifyCharUuid = Guid("0000FFE1-0000-1000-8000-00805F9B34FB");

  StreamSubscription<List<int>>? _notifySubscription;
  final List<void Function(List<int>)> _notifyCallbacks = [];

  Future<bool> scanAndConnect() async {
    bool connected = false;
    print("🔍 BLE 스캔 시작...");
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

    try {
      await for (final scanResultList in FlutterBluePlus.scanResults) {
        for (final result in scanResultList) {
          final matched = result.advertisementData.serviceUuids.any((uuid) =>
          uuid.toString().toLowerCase() == serviceUuid.toString().toLowerCase());

          if (matched) {
            await FlutterBluePlus.stopScan();
            connectedDevice = result.device;
            await connectedDevice!.connect();
            print("연결된 기기: ${connectedDevice!.name}");

            List<BluetoothService> services = await connectedDevice!.discoverServices();
            for (var service in services) {
              if (service.uuid == serviceUuid) {
                for (var characteristic in service.characteristics) {
                  if (characteristic.uuid == writeCharUuid) {
                    writeCharacteristic = characteristic;
                  }
                  if (characteristic.uuid == notifyCharUuid && characteristic.properties.notify) {
                    notifyCharacteristic = characteristic;
                  }
                }
              }
            }

            _subscribeToNotifyOnce();
            connected = true;
            break;
          }
        }
        if (connected) break;
      }
    } catch (e) {
      print("BLE 연결 실패: $e");
    }

    return connected;
  }

  void _subscribeToNotifyOnce() {
    if (_notifySubscription != null) return;

    if (notifyCharacteristic != null) {
      notifyCharacteristic!.setNotifyValue(true);
      _notifySubscription = notifyCharacteristic!.onValueReceived.listen((value) {
        for (final cb in _notifyCallbacks) {
          cb(value);
        }
      });
      print("Notify 구독 시작됨");
    } else {
      print("notifyCharacteristic이 null입니다.");
    }
  }

  void addNotifyCallback(void Function(List<int>) callback) {
    if (!_notifyCallbacks.contains(callback)) {
      _notifyCallbacks.add(callback);
    }
  }

  void removeNotifyCallback(void Function(List<int>) callback) {
    _notifyCallbacks.remove(callback);
  }

  Future<void> cancelNotifySubscription() async {
    await _notifySubscription?.cancel();
    _notifySubscription = null;
    print("Notify 구독 해제됨");
  }

  /// 문자열을 BLE로 전송
  Future<void> write(String message) async {
    if (writeCharacteristic != null) {
      await writeCharacteristic!.write(utf8.encode(message), withoutResponse: true);
      print("BLE 문자열 전송: $message");
    } else {
      print("writeCharacteristic이 null입니다.");
    }
  }

  /// 바이너리 데이터 전송 (기존 sendData 유지)
  Future<void> sendData(List<int> data) async {
    if (writeCharacteristic != null) {
      await writeCharacteristic!.write(data, withoutResponse: true);
      print("BLE 데이터 전송: $data");
    } else {
      print("writeCharacteristic이 null입니다.");
    }
  }

  Future<void> disconnect() async {
    await cancelNotifySubscription();
    if (connectedDevice != null) {
      await connectedDevice!.disconnect();
    }
    connectedDevice = null;
    writeCharacteristic = null;
    notifyCharacteristic = null;
    print("BLE 연결 해제됨");
  }

  /// 긴급 메시지 또는 FALL 수신 시 Alert 표시
  void startListeningToNotifications(BuildContext context, String lat, String lon) {
    _subscribeToNotifyOnce();

    addNotifyCallback((List<int> value) {
      try {
        String received = utf8.decode(value).trim();
        print("BLE 수신: $received");

        if (received.toLowerCase() == 'emergency') {
          AlertHelper.showEmergencyAlert(context, this); // BleManager 인스턴스 전달
        } else if (received.toLowerCase().startsWith('fall')) {
          AlertHelper.showWarningAlert(context, lat, lon);
        }
      } catch (e) {
        print("수신 메시지 디코딩 오류: $e");
      }
    });
  }
}
