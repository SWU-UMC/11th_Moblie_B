import 'package:flutter/material.dart';

class EditProfileButton extends StatelessWidget {
  const EditProfileButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

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
