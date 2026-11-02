import 'package:flutter/material.dart';
//import 'screens/profile_screen.dart';
import 'screens/start_screen.dart';
import 'theme/app_theme.dart';

void main() => runApp(const MovieLogApp());

class MovieLogApp extends StatelessWidget {
  const MovieLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MovieLog',
      theme: AppTheme.light,
      // 프로필 화면을 확인할 때는 home을 const ProfileScreen()으로 바꿉니다.
      // 화면 전환은 3주차에서 연결합니다.
      home: const StartScreen(),
      //home: const ProfileScreen(),
    );
  }
}
