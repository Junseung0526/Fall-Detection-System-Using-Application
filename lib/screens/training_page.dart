import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/ble_manager.dart';
import '../utils/gyro_simulator.dart';

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

  double gyroX = 0, gyroY = 0, gyroZ = 0;

  final List<TrainingRecord> _records = [];

  final BleManager _bleManager = BleManager();
  late GyroSimulator _gyroSimulator;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

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

    _gyroSimulator = GyroSimulator(
      bleManager: _bleManager,
      onUpdate: (x, y, z) {
        setState(() {
          gyroX = x;
          gyroY = y;
          gyroZ = z;
        });
        _checkGyroThreshold();
      },
    );

    _gyroSimulator.startListening();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _timer?.cancel();
    _gyroSimulator.stopListening();
    _bleManager.disconnect();
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
  }

  void _stopTraining() {
    _animationController.stop();
    _timer?.cancel();

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
                final formattedTime =
                    "${rec.timestamp.year}-${rec.timestamp.month.toString().padLeft(2, '0')}-${rec.timestamp.day.toString().padLeft(2, '0')} "
                    "${rec.timestamp.hour.toString().padLeft(2, '0')}:${rec.timestamp.minute.toString().padLeft(2, '0')}:${rec.timestamp.second.toString().padLeft(2, '0')}";
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
    double val = gyroX.clamp(-150, 150);
    return (val / 150) * 20;
  }

  Widget _buildGyroValue(String label, double value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(value.toStringAsFixed(2), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("균형 훈련"),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _records.isEmpty ? null : _showRecordsDialog,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
              child: Icon(
                _isTraining ? Icons.accessibility_new : Icons.accessibility,
                size: 120,
                color: _isTraining ? Colors.blue : Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                _isTraining ? "훈련 진행 중" : "대기 상태",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: _isTraining ? Colors.green : Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text("버틴 시간", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 10),
                    Text(
                      "$_secondsHeld 초",
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              color: Colors.grey[100],
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("자이로 센서 값", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildGyroValue("X", gyroX),
                        _buildGyroValue("Y", gyroY),
                        _buildGyroValue("Z", gyroZ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _isTraining ? _stopTraining : _startTraining,
                  icon: Icon(_isTraining ? Icons.stop : Icons.play_arrow),
                  label: Text(_isTraining ? "훈련 중지" : "훈련 시작"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isTraining ? Colors.redAccent : Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                    textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
