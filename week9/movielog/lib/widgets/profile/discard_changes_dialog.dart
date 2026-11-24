import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../movielog_button.dart';

/// W8-CH05 변경 내용 버리기 Dialog
/// 나가기 → true (마이페이지로), 계속 수정 → false (그대로 머묾)
/// 7주차 삭제 확인 Dialog랑 같은 틀 (inset 31, radius 20, 버튼 44)
class DiscardChangesDialog extends StatelessWidget {
  const DiscardChangesDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.barrier,
      builder: (_) => const DiscardChangesDialog(),
    );
    return result ?? false; // 바깥 탭으로 닫으면 계속 수정
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: AppColors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 31, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 36, 18, 37),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '변경 내용을 버릴까요?',
              textAlign: TextAlign.center,
              style: textTheme.titleLarge?.copyWith(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 19),
            Text(
              '저장하지 않은 내용은 사라집니다.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                letterSpacing: 0,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 56),
            Row(
              children: [
                Expanded(
                  child: MovieLogButton(
                    label: '계속 수정',
                    variant: MovieLogButtonVariant.tonal,
                    borderRadius: 8,
                    fontSize: 14,
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: MovieLogButton(
                    label: '나가기',
                    borderRadius: 8,
                    fontSize: 14,
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
