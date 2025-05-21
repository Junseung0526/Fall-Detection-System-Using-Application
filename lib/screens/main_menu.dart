import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'training_page.dart';
import '../utils/ble_manager.dart';
import '../utils/alert_helper.dart';
import '../utils/constants.dart';

class MainMenu extends StatefulWidget {
  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  final BleManager bleManager = BleManager();
  final TextEditingController _guardianController = TextEditingController();

  bool _isScanning = false;
  BluetoothDevice? _device;
  String? _savedGuardianContact;
  bool _isEditingContact = false;

  static const String _prefsKey = 'guardian_contact';

  @override
  void initState() {
    super.initState();
    _loadGuardianContact();
  }

  Future<void> _loadGuardianContact() async {
    final prefs = await SharedPreferences.getInstance();
    final contact = prefs.getString(_prefsKey);
    setState(() {
      _savedGuardianContact = contact;
      _isEditingContact = contact == null || contact.isEmpty;
    });
  }

  Future<void> _saveGuardianContact() async {
    final input = _guardianController.text.trim();

    if (input.isEmpty) {
      _showSnackBar("보호자 연락처를 입력해주세요.");
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, input);

    setState(() {
      _savedGuardianContact = input;
      _isEditingContact = false;
    });

    FocusScope.of(context).unfocus();
    _showSnackBar("보호자 연락처가 저장되었습니다: $input");
  }

  void _startEditingContact() {
    _guardianController.text = _savedGuardianContact ?? '';
    setState(() {
      _isEditingContact = true;
    });
  }

  void _connectToBle() async {
    if (_isScanning) return;

    setState(() => _isScanning = true);

    bool success = false;
    int retryCount = 0;
    const maxRetries = 5;

    while (!success && retryCount < maxRetries) {
      success = await bleManager.scanAndConnect(Constants.bleDeviceName);
      retryCount++;
      if (!success) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    setState(() {
      _isScanning = false;
      _device = success ? bleManager.connectedDevice : null;
    });

    _showSnackBar(success
        ? "BLE 연결 성공: ${_device?.name ?? '알 수 없음'}"
        : "BLE 연결 실패: 재시도 $retryCount회 실패");
  }

  void _showWarningDialog() {
    if (_savedGuardianContact == null || _savedGuardianContact!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('보호자 연락처를 먼저 등록해주세요.')),
      );
      return;
    }

    AlertHelper.showWarningAlert(context);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _guardianController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("낙상 감지 훈련 앱"),
        backgroundColor: Colors.blueAccent,
        elevation: 4,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 50),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildGuardianContactSection(),
            const SizedBox(height: 50),
            _buildBleButton(),
            const SizedBox(height: 80),
            _buildTrainingButton(),
            const SizedBox(height: 60),
            _buildWarningTestButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildGuardianContactSection() {
    final buttonRadius = BorderRadius.circular(16);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "보호자 연락처",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 10),
        if (_isEditingContact)
          Column(
            children: [
              TextField(
                controller: _guardianController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  hintText: "보호자 전화번호 입력",
                  prefixIcon: const Icon(Icons.phone),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveGuardianContact,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.teal,
                    shape: RoundedRectangleBorder(borderRadius: buttonRadius),
                    elevation: 6,
                  ),
                  child: const Text(
                    "보호자 연락처 저장",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _savedGuardianContact ?? '',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                TextButton(
                  onPressed: _startEditingContact,
                  child: const Text(
                    "수정",
                    style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildBleButton() {
    final buttonRadius = BorderRadius.circular(16);
    final isConnected = _device != null;

    return ElevatedButton(
      onPressed: (isConnected || _isScanning) ? null : _connectToBle,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 18),
        backgroundColor: isConnected ? Colors.green : Colors.blueAccent,
        shape: RoundedRectangleBorder(borderRadius: buttonRadius),
        elevation: 6,
      ),
      child: Text(
        isConnected
            ? "  BLE 연결됨: ${_device!.name}  "
            : (_isScanning ? "  검색 중...  " : "  BLE 연결  "),
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildTrainingButton() {
    final buttonRadius = BorderRadius.circular(16);

    return ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => TrainingPage()),
        );
      },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 18),
        backgroundColor: Colors.blueAccent,
        shape: RoundedRectangleBorder(borderRadius: buttonRadius),
        elevation: 6,
      ),
      child: const Text(
        "  훈련 시작 화면으로 이동  ",
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black),
      ),
    );
  }

  Widget _buildWarningTestButton() {
    final buttonRadius = BorderRadius.circular(16);

    return ElevatedButton(
      onPressed: _showWarningDialog,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: Colors.redAccent,
        shape: RoundedRectangleBorder(borderRadius: buttonRadius),
        elevation: 6,
      ),
      child: const Text(
        "  ⚠️ 경고 알림 테스트  ",
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black),
      ),
    );
  }
}
