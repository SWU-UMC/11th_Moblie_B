import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 테두리만 있는 프로필 수정 버튼 (Figma W8-06: 128 x 40, radius 9, 15 Bold)
/// 내 정보 불러온 뒤에만 onPressed 넣음 (null이면 비활성)
class EditProfileButton extends StatelessWidget {
  const EditProfileButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 128,
      height: 40,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.violet,
          padding: EdgeInsets.zero,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
          side: const BorderSide(color: AppColors.violet),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
        child: const Text('프로필 수정'),
      ),
    );
  }
}
