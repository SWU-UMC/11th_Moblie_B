import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';

void main() => runApp(MovieLogApp());

class MovieLogApp extends StatelessWidget {
  /// 테스트에서는 새 Router를 넘겨 매번 처음 위치에서 시작합니다.
  MovieLogApp({super.key, GoRouter? router})
    : router = router ?? AppRouter.router;

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    // 화면 이동과 첫 화면은 MaterialApp이 아니라 GoRouter가 관리합니다.
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'MovieLog',
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
