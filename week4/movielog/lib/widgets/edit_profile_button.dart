import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 화면의 보조 동작이라 배경 없는 TextButton에 테두리만 더해 사용
class EditProfileButton extends StatelessWidget {
  const EditProfileButton({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {}, // 1주차에는 모양만 구현합니다.
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
