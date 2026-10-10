import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// 영화 목록 Error 상태: 내부 오류 내용 대신 안내 문구와 다시 시도 버튼을 보여줍니다.
class MovieListError extends StatelessWidget {
  const MovieListError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: AppColors.violet),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}
