import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/main_menu.dart';

Future<void> requestPermissions() async {
  // Android 12 (API 31) 이상: 별도 BLE 권한 필요
  Map<Permission, PermissionStatus> statuses = await [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.locationWhenInUse,
  ].request();

  // 권한 결과 확인 및 로그 출력 (필요시 추가 처리 가능)
  statuses.forEach((permission, status) {
    if (!status.isGranted) {
      debugPrint('권한 거부됨: $permission');
    } else {
      debugPrint('권한 허용됨: $permission');
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Flutter 엔진 초기화
  await requestPermissions(); // 권한 요청
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '낙상 감지 훈련 앱',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      home: const MainMenu(),
    );
  }
}
