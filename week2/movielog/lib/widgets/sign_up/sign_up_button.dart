import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// 가입하기 버튼. [onPressed]가 null이면 비활성화됩니다.
class SignUpButton extends StatelessWidget {
  const SignUpButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 56),
          backgroundColor: AppColors.violet,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.disabledButton,
          disabledForegroundColor: AppColors.white,
          textStyle: Theme.of(context).textTheme.titleMedium,
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text('가입하기'),
      ),
    );
  }
}
