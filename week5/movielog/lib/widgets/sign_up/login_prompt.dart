import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// "이미 계정이 있나요? 로그인" 안내 (로그인 화면 연결은 이후 주차)
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
          onTap: () {},
          child: Text('로그인', style: style?.copyWith(color: AppColors.violet)),
        ),
      ],
    );
  }
}
