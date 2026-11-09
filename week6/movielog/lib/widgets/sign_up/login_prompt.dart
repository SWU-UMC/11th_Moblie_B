import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// '이미 계정이 있나요? 로그인' (로그인 연결은 나중에 함)
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
