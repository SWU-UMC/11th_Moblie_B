import 'package:flutter/material.dart';

class EditProfileButton extends StatelessWidget {
  const EditProfileButton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {}, // 1주차에는 화면 이동이나 저장 기능을 연결하지 않습니다.
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
        ),
        child: const Text('프로필 수정'),
      ),
    );
  }
}
