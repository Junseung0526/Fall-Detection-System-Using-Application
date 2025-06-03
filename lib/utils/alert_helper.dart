import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'ble_manager.dart'; // BleManager 사용 위해 import

final AudioPlayer audioPlayer = AudioPlayer();

void playAlertSound() async {
  await audioPlayer.setReleaseMode(ReleaseMode.loop);
  await audioPlayer.play(AssetSource('sounds/alarm.wav'));
}

void stopAlertSound() async {
  await audioPlayer.stop();
}

class AlertHelper {
  static const String _prefsKey = 'guardian_contact';

  /// 낙상 감지 경고 (위치 포함)
  static void showWarningAlert(BuildContext context, String latitude, String longitude) async {
    final prefs = await SharedPreferences.getInstance();
    final guardianPhoneNumber = prefs.getString(_prefsKey);

    if (guardianPhoneNumber == null || guardianPhoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('보호자 연락처가 등록되어 있지 않습니다.')),
      );
      return;
    }

    int countdown = 10;
    Timer? countdownTimer;

    playAlertSound();

    Future<void> sendAlertToGuardian() async {
      final message = '낙상이 감지되었습니다!\n위치: https://maps.google.com/?q=$latitude,$longitude';

      final Uri smsUri = Uri(
        scheme: 'sms',
        path: guardianPhoneNumber,
        queryParameters: {'body': message},
      );

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri, mode: LaunchMode.externalApplication);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('보호자에게 연락을 보냈습니다!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMS 전송에 실패했습니다.')),
        );
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
              countdown--;
              if (countdown <= 0) {
                timer.cancel();
                Navigator.of(context).pop();
                stopAlertSound();
                sendAlertToGuardian();
              } else {
                setState(() {});
              }
            });

            return AlertDialog(
              title: const Text("낙상 경고"),
              content: Text("보호자에게 자동으로 메시지를 보냅니다: $countdown 초 후"),
              actions: [
                TextButton(
                  onPressed: () {
                    countdownTimer?.cancel();
                    stopAlertSound();
                    Navigator.of(context).pop();
                  },
                  child: const Text("취소"),
                ),
                TextButton(
                  onPressed: () {
                    countdownTimer?.cancel();
                    stopAlertSound();
                    Navigator.of(context).pop();
                    sendAlertToGuardian();
                  },
                  child: const Text("즉시 보내기"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 긴급 상황 감지 알림 (위치 없이, 상태 변경 포함)
  static void showEmergencyAlert(BuildContext context, BleManager bleManager) async {
    final prefs = await SharedPreferences.getInstance();
    final guardianPhoneNumber = prefs.getString(_prefsKey);

    if (guardianPhoneNumber == null || guardianPhoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('보호자 연락처가 등록되어 있지 않습니다.')),
      );
      return;
    }

    int countdown = 10;
    Timer? countdownTimer;

    playAlertSound();

    Future<void> sendEmergencyMessage() async {
      final message = '긴급 상황이 감지되었습니다! 빠른 확인이 필요합니다.';

      final Uri smsUri = Uri(
        scheme: 'sms',
        path: guardianPhoneNumber,
        queryParameters: {'body': message},
      );

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri, mode: LaunchMode.externalApplication);
        bleManager.write("normal");                                             // 상태 복구 메시지 BLE로 전송
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('보호자에게 긴급 메시지를 보냈습니다!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMS 전송에 실패했습니다.')),
        );
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
              countdown--;
              if (countdown <= 0) {
                timer.cancel();
                Navigator.of(context).pop();
                stopAlertSound();
                sendEmergencyMessage();
              } else {
                setState(() {});
              }
            });

            return AlertDialog(
              title: const Text("⚠️ 긴급 상황 감지"),
              content: Text("보호자에게 자동으로 메시지를 보냅니다: $countdown 초 후"),
              actions: [
                TextButton(
                  onPressed: () {
                    countdownTimer?.cancel();
                    stopAlertSound();
                    Navigator.of(context).pop();
                  },
                  child: const Text("취소"),
                ),
                TextButton(
                  onPressed: () {
                    countdownTimer?.cancel();
                    stopAlertSound();
                    Navigator.of(context).pop();
                    sendEmergencyMessage();
                  },
                  child: const Text("즉시 보내기"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
