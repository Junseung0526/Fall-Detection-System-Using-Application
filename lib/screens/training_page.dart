import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/ble_manager.dart';
import '../utils/alert_helper.dart';

class TrainingRecord {
  final int seconds;
  final DateTime timestamp;
  TrainingRecord(this.seconds, this.timestamp);
}

class TrainingPage extends StatefulWidget {
  final BleManager bleManager;
  const TrainingPage({super.key, required this.bleManager});

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

    widget.bleManager.addNotifyCallback(_onBleNotify);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _timer?.cancel();
    widget.bleManager.removeNotifyCallback(_onBleNotify);
    super.dispose();
  }

  void _onBleNotify(List<int> value) {
    final data = utf8.decode(value).trim();
    print("\u{1F4F2} TrainingPage BLE 수신: $data");

    if (data == "emergency") {
      if (!mounted) return;
      playAlertSound();
      AlertHelper.showEmergencyAlert(context, widget.bleManager);
      return;
    }

    if (data.startsWith("FALL:")) {
      final parts = data.replaceFirst("FALL:", "").split(",");
      if (parts.length == 2) {
        final lat = parts[0].trim();
        final lon = parts[1].trim();
        if (!mounted) return;
        playAlertSound();
        AlertHelper.showWarningAlert(context, lat, lon);
      }
      return;
    }

    final parts = data.split(",");
    if (parts.length >= 3) {
      try {
        final gx = double.parse(parts[0]);
        final gy = double.parse(parts[1]);
        final gz = double.parse(parts[2]);

        setState(() {
          gyroX = gx;
          gyroY = gy;
          gyroZ = gz;
        });

        _checkGyroThreshold();
      } catch (e) {
        print("자이로 데이터 파싱 오류: $e");
      }
    }
  }

  void _startTraining() {
    setState(() {
      _isTraining = true;
      _secondsHeld = 0;
    });

    _animationController.forward();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _secondsHeld++);
    });
  }

  void _stopTraining() {
    _animationController.stop();
    _timer?.cancel();

    if (_secondsHeld > 0) {
      setState(() {
        _records.insert(0, TrainingRecord(_secondsHeld, DateTime.now()));
      });
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
                final time = rec.timestamp;
                final formatted = "${_pad(time.year)}-${_pad(time.month)}-${_pad(time.day)} ${_pad(time.hour)}:${_pad(time.minute)}:${_pad(time.second)}";
                return ListTile(
                  leading: const Icon(Icons.history),
                  title: Text('${rec.seconds} 초 버팀'),
                  subtitle: Text(formatted),
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

  String _pad(int n) => n.toString().padLeft(2, '0');

  double _calculateAnimationOffset() {
    double val = gyroX.clamp(-150, 150);
    return (val / 150) * 20;
  }

  Widget _buildGyroValue(String label, double value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 18, color: Colors.lightBlueAccent, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value.toStringAsFixed(2), style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildRecordList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("훈련 기록", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: ListView.builder(
            itemCount: _records.length,
            itemBuilder: (context, index) {
              final rec = _records[index];
              final time = rec.timestamp;
              final formatted = "${_pad(time.year)}-${_pad(time.month)}-${_pad(time.day)} ${_pad(time.hour)}:${_pad(time.minute)}:${_pad(time.second)}";
              return ListTile(
                leading: const Icon(Icons.check_circle_outline, color: Colors.lightGreenAccent),
                title: Text('${rec.seconds} 초 버팀', style: const TextStyle(color: Colors.white)),
                subtitle: Text(formatted, style: const TextStyle(color: Colors.white60)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
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
                color: _isTraining ? Colors.blueAccent : Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                _isTraining ? "훈련 진행 중" : "대기 상태",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _isTraining ? Colors.greenAccent : Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.deepPurple.shade700,
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text("⏱️ 현재 버틴 시간", style: TextStyle(fontSize: 22, color: Colors.white70, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text("$_secondsHeld 초",
                      style: const TextStyle(
                        fontSize: 40,
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(blurRadius: 4, color: Colors.black, offset: Offset(2, 2)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              color: Colors.grey.shade900,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("🧭 자이로 센서 값", style: TextStyle(fontSize: 18, color: Colors.white70, fontWeight: FontWeight.bold)),
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
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _isTraining ? _stopTraining : _startTraining,
                  icon: Icon(_isTraining ? Icons.stop_circle : Icons.play_circle_fill, size: 28),
                  label: Text(_isTraining ? "중지" : "시작"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isTraining ? Colors.redAccent : Colors.greenAccent[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 40),
                    textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_records.isNotEmpty) _buildRecordList(),
          ],
        ),
      ),
    );
  }
}
