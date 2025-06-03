  import 'dart:convert';
  import '../utils/ble_manager.dart';
  
  typedef GyroUpdateCallback = void Function(double x, double y, double z);
  
  class GyroSimulator {
    final BleManager bleManager;
    final GyroUpdateCallback onUpdate;
  
    // 콜백을 추적할 수 있도록 별도 함수로 저장
    late final void Function(List<int>) _notifyHandler;
  
    GyroSimulator({required this.bleManager, required this.onUpdate}) {
      _notifyHandler = _handleNotify;
    }
  
    void startListening() {
      bleManager.addNotifyCallback(_notifyHandler);
      print('[GyroSimulator] ✅ 콜백 등록됨');
    }
  
    void stopListening() {
      bleManager.removeNotifyCallback(_notifyHandler);
      print('[GyroSimulator] 🔕 콜백 해제됨');
    }
  
    void _handleNotify(List<int> value) {
      try {
        print('[GyroSimulator] 📥 수신된 raw bytes: $value');
        String dataStr = utf8.decode(value).trim();
        print('[GyroSimulator] 📄 수신된 문자열: "$dataStr"');
  
        List<String> parts = dataStr.split(',');
        if (parts.length == 3) {
          double x = double.parse(parts[0]);
          double y = double.parse(parts[1]);
          double z = double.parse(parts[2]);
          print('[GyroSimulator] ✅ 파싱 완료: x=$x, y=$y, z=$z');
          onUpdate(x, y, z);
        } else {
          print('[GyroSimulator] ⚠️ 데이터 형식 오류: 3개 미만 요소');
        }
      } catch (e) {
        print('[GyroSimulator] ❌ 자이로 데이터 파싱 실패: $e');
      }
    }
  }
