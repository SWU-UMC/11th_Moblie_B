import 'package:flutter/material.dart';

class EditProfileButton extends StatelessWidget {
  const EditProfileButton({super.key, required this.onPressed});

  /// null이면 비활성입니다. (내 정보를 아직 받지 못한 경우)
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(120, 44),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        foregroundColor: colors.primary,
        side: BorderSide(color: colors.primary),
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
      child: const Text('프로필 수정'),
    );
  }
}
