import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import '../../router/app_routes.dart';
import '../../theme/app_colors.dart';

/// '이미 계정이 있나요? 로그인'
/// 로그인 화면에서 push로 왔으면 pop, 아니면 /login으로
class LoginPrompt extends StatelessWidget {
  const LoginPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('이미 계정이 있나요? ', style: style),
        GestureDetector(
          onTap: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.login),
          child: Text('로그인', style: style?.copyWith(color: AppColors.violet)),
        ),
      ],
    );
  }
}
