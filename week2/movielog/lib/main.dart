import 'package:flutter/material.dart';

import 'screens/sign_up_screen.dart';
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
      // 다른 화면을 확인할 때는 home을 바꿉니다. (화면 전환은 3주차)
      // StartScreen(), ProfileScreen()
      home: const SignUpScreen(),
    );
  }
}
