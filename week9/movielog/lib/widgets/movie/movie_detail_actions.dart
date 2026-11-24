import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// 상세 하단 고정 "평점 남기기"
/// 9주차: 3주차 mock 즐겨찾기 버튼 빠짐 → 제목 옆 북마크(FavoriteButton)로 이동
/// 남은 평점 버튼이 전체 너비 사용
class MovieDetailActions extends StatelessWidget {
  const MovieDetailActions({super.key, required this.onRatePressed});

  /// null이면 평점 남기기 비활성화 (이미 등록한 영화)
  final VoidCallback? onRatePressed;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.titleMedium;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.warmWhite,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onRatePressed,
              icon: const Icon(Icons.rate_review_outlined),
              label: const Text('평점 남기기'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 48),
                backgroundColor: AppColors.violet,
                foregroundColor: AppColors.white,
                disabledBackgroundColor: AppColors.disabledButton,
                disabledForegroundColor: AppColors.white,
                textStyle: textStyle,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
