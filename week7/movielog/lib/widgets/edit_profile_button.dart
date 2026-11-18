import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 테두리만 있는 TextButton
class EditProfileButton extends StatelessWidget {
  const EditProfileButton({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {}, // 1주차는 UI만 구현
      style: TextButton.styleFrom(
        foregroundColor: AppColors.violet,
        textStyle: Theme.of(context).textTheme.titleMedium,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        side: const BorderSide(color: AppColors.violet),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text('프로필 수정'),
    );
  }
}
