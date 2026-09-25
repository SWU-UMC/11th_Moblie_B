import 'package:flutter/material.dart';

class EditProfileButton extends StatelessWidget {
  const EditProfileButton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        // 수정 기능이 아직 없으므로, 눌러도 반응하지 않는 버튼이 활성화되어 보이지 않게 비활성화합니다.
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
        ),
        child: const Text('프로필 수정'),
      ),
    );
  }
}
