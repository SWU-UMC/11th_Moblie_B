import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// 요청 실패 재시도 Dialog (W5-01). 다시 시도를 누르면 true, 취소는 false를 반환합니다.
class RetryDialog extends StatelessWidget {
  const RetryDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final retry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const RetryDialog(),
    );
    return retry ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.violetLight,
              child: Icon(Icons.refresh, color: AppColors.violet),
            ),
            const SizedBox(height: 16),
            Text('영화를 불러오지 못했어요', style: textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              '네트워크 상태를 확인하고\n다시 시도해 주세요.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      backgroundColor: AppColors.violetLight,
                      foregroundColor: AppColors.violetDark,
                    ),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      backgroundColor: AppColors.violet,
                    ),
                    child: const Text('다시 시도'),
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
