import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class AlertHelper {
  static const String _prefsKey = 'guardian_contact';

  static void showWarningAlert(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final guardianPhoneNumber = prefs.getString(_prefsKey);

    if (guardianPhoneNumber == null || guardianPhoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('보호자 연락처가 등록되어 있지 않습니다.')),
      );
      return;
    }

    Timer? countdownTimer;
    int countdown = 10;

    Future<void> sendAlertToGuardian() async {
      const message = '낙상이 감지되었습니다! 즉시 확인해주세요.';

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
            if (countdownTimer == null) {
              countdownTimer =
                  Timer.periodic(const Duration(seconds: 1), (timer) {
                    countdown--;
                    if (countdown <= 0) {
                      timer.cancel();
                      Navigator.of(context).pop();
                      sendAlertToGuardian();
                    } else {
                      setState(() {});
                    }
                  });
            }

            return AlertDialog(
              title: const Text("낙상 경고"),
              content: Text("보호자에게 자동으로 메시지를 보냅니다: $countdown 초 후"),
              actions: [
                TextButton(
                  onPressed: () {
                    countdownTimer?.cancel();
                    Navigator.of(context).pop();
                  },
                  child: const Text("취소"),
                ),
                TextButton(
                  onPressed: () {
                    countdownTimer?.cancel();
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
}