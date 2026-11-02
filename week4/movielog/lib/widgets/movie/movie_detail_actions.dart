import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// 상세 화면 아래에 고정되는 즐겨찾기 / 평점 남기기 버튼
class MovieDetailActions extends StatelessWidget {
  const MovieDetailActions({
    super.key,
    required this.isFavorite,
    required this.onFavoritePressed,
    required this.onRatePressed,
  });

  final bool isFavorite;
  final VoidCallback onFavoritePressed;
  final VoidCallback onRatePressed;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.titleMedium;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(999),
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.warmWhite,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onFavoritePressed,
                  icon: Icon(
                    isFavorite ? Icons.bookmark : Icons.bookmark_border,
                  ),
                  label: Text(isFavorite ? '즐겨찾기됨' : '즐겨찾기'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    foregroundColor: AppColors.violet,
                    side: const BorderSide(color: AppColors.violet),
                    textStyle: textStyle,
                    shape: shape,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onRatePressed,
                  icon: const Icon(Icons.rate_review_outlined),
                  label: const Text('평점 남기기'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor: AppColors.violetDark,
                    foregroundColor: AppColors.white,
                    textStyle: textStyle,
                    shape: shape,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
