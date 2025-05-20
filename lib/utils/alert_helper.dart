import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AlertHelper {
  static void showWarningAlert(BuildContext context,
      String guardianPhoneNumber) {
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
            // 타이머는 이곳에서 한 번만 생성
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
              title: const Text("⚠️ 경고 알림"),
              content: Text(
                  "낙상이 감지되었습니다!\n10초 안에 취소하지 않으면 보호자에게 자동으로 연락이 갑니다.\n\n남은 시간: $countdown 초"),
              actions: [
                TextButton(
                  onPressed: () {
                    countdownTimer?.cancel();
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('경고 알림이 취소되었습니다.')),
                    );
                  },
                  child: const Text(
                    "취소",
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      countdownTimer?.cancel();
    });
  }
}