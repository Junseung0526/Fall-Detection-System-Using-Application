import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

class TrainingRecord {
  final int seconds;
  final DateTime timestamp;

  TrainingRecord(this.seconds, this.timestamp);
}

class TrainingPage extends StatefulWidget {
  @override
  State<TrainingPage> createState() => _TrainingPageState();
}

class _TrainingPageState extends State<TrainingPage> with TickerProviderStateMixin {
  static const double gyroThreshold = 100.0;

  late AnimationController _animationController;
  late Animation<double> _moveAnimation;

  int _secondsHeld = 0;
  bool _isTraining = false;
  Timer? _timer;

  final _rand = Random();
  double gyroX = 0, gyroY = 0, gyroZ = 0;
  Timer? _gyroTimer;

  // 최근 기록 리스트 (임시 메모리 저장)
  final List<TrainingRecord> _records = [];

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // 좌우로 움직이는 Tween 애니메이션
    _moveAnimation = Tween<double>(begin: -20, end: 20).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animationController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _timer?.cancel();
    _gyroTimer?.cancel();
    super.dispose();
  }

  void _startTraining() {
    setState(() {
      _isTraining = true;
      _secondsHeld = 0;
    });

    _animationController.forward();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _secondsHeld++);
    });

    _startGyroSimulator();
  }

  void _stopTraining() {
    _animationController.stop();
    _timer?.cancel();
    _gyroTimer?.cancel();

    // 기록 저장
    if (_secondsHeld > 0) {
      _records.insert(0, TrainingRecord(_secondsHeld, DateTime.now()));
    }

    setState(() {
      _isTraining = false;
      gyroX = 0;
      gyroY = 0;
      gyroZ = 0;
    });
  }

  void _startGyroSimulator() {
    _gyroTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      setState(() {
        gyroX = (_rand.nextDouble() * 2 - 1) * 150;
        gyroY = (_rand.nextDouble() * 2 - 1) * 150;
        gyroZ = (_rand.nextDouble() * 2 - 1) * 150;
      });
      _checkGyroThreshold();
    });
  }

  void _checkGyroThreshold() {
    double maxAbsValue = [gyroX.abs(), gyroY.abs(), gyroZ.abs()].reduce(max);
    if (maxAbsValue >= gyroThreshold && _isTraining) {
      _stopTraining();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("불균형 감지! 훈련이 자동 종료되었습니다.")),
      );
    }
  }

  void _showRecordsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('최근 훈련 기록'),
          content: SizedBox(
            width: double.maxFinite,
            child: _records.isEmpty
                ? const Text('기록이 없습니다.')
                : ListView.builder(
              shrinkWrap: true,
              itemCount: _records.length,
              itemBuilder: (context, index) {
                final rec = _records[index];
                final formattedTime = "${rec.timestamp.year}-${rec.timestamp.month.toString().padLeft(2,'0')}-${rec.timestamp.day.toString().padLeft(2,'0')} "
                    "${rec.timestamp.hour.toString().padLeft(2,'0')}:${rec.timestamp.minute.toString().padLeft(2,'0')}:${rec.timestamp.second.toString().padLeft(2,'0')}";
                return ListTile(
                  leading: Icon(Icons.history),
                  title: Text('${rec.seconds} 초 버팀'),
                  subtitle: Text(formattedTime),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            )
          ],
        );
      },
    );
  }

  double _calculateAnimationOffset() {
    // gyroX 값에 따라 -20 ~ +20 범위 좌우 흔들림 (비례제어)
    double val = gyroX.clamp(-150, 150);
    return (val / 150) * 20;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("훈련 화면"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                double offsetX = _calculateAnimationOffset() * (_animationController.value * 2 - 1);
                return Transform.translate(
                  offset: Offset(offsetX, 0),
                  child: child,
                );
              },
              child: const Icon(Icons.accessibility_new, size: 120, color: Colors.blue),
            ),
            const SizedBox(height: 20),
            Text(
              "버틴 시간: $_secondsHeld 초",
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text(
              "자이로 센서 값\nX: ${gyroX.toStringAsFixed(2)}\nY: ${gyroY.toStringAsFixed(2)}\nZ: ${gyroZ.toStringAsFixed(2)}",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _isTraining ? _stopTraining : _startTraining,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 30),
                    backgroundColor: _isTraining ? Colors.redAccent : Colors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _isTraining ? "  훈련 중지  " : "  훈련 시작  ",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black),
                  ),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: _records.isEmpty ? null : _showRecordsDialog,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 30),
                    backgroundColor: Colors.deepPurpleAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    "  최근 기록 보기  ",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
