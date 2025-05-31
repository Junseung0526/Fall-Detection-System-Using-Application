import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_manager.dart';

typedef GyroUpdateCallback = void Function(double x, double y, double z);

class GyroSimulator {
  final BleManager bleManager;
  final GyroUpdateCallback onUpdate;
  StreamSubscription<List<int>>? _subscription;

  GyroSimulator({required this.bleManager, required this.onUpdate});

  void startListening() {
    final notifyStream = bleManager.notifyStream;
    if (notifyStream == null) {
      print('[GyroSimulator] Notify 스트림이 존재하지 않습니다.');
      return;
    }

    print('[GyroSimulator] Notify 스트림 구독 시작');

    _subscription = notifyStream.listen((value) {
      try {
        // 디버깅용: byte -> hex 출력
        print('[GyroSimulator] 수신된 raw bytes: $value');

        String dataStr = utf8.decode(value).trim();
        print('[GyroSimulator] 수신된 문자열: "$dataStr"');

        List<String> parts = dataStr.split(',');
        if (parts.length == 3) {
          double x = double.parse(parts[0]);
          double y = double.parse(parts[1]);
          double z = double.parse(parts[2]);
          print('[GyroSimulator] 파싱 완료: x=$x, y=$y, z=$z');
          onUpdate(x, y, z);
        } else {
          print('[GyroSimulator] 데이터 형식 오류: 3개 미만 요소');
        }
      } catch (e) {
        print('[GyroSimulator] 자이로 데이터 파싱 실패: $e');
      }
    }, onError: (err) {
      print('[GyroSimulator] Notify 스트림 오류: $err');
    });
  }

  void stopListening() {
    print('[GyroSimulator] Notify 구독 해제');
    _subscription?.cancel();
    _subscription = null;
  }
}
