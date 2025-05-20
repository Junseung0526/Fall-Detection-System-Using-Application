import 'dart:async';
import 'dart:math';

typedef GyroUpdateCallback = void Function(double x, double y, double z);

class GyroSimulator {
  final Random _rand = Random();
  final GyroUpdateCallback onUpdate;
  Timer? _timer;

  GyroSimulator({required this.onUpdate});

  void start() {
    _timer = Timer.periodic(Duration(milliseconds: 500), (_) {
      double x = (_rand.nextDouble() * 2 - 1) * 90; // -90 ~ 90
      double y = (_rand.nextDouble() * 2 - 1) * 90;
      double z = (_rand.nextDouble() * 2 - 1) * 180;
      onUpdate(x, y, z);
    });
  }

  void stop() {
    _timer?.cancel();
  }
}
