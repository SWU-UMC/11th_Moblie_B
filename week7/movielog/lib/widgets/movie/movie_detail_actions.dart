import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// 상세 하단 고정 버튼 (즐겨찾기 / 평점 남기기)
class MovieDetailActions extends StatelessWidget {
  const MovieDetailActions({
    super.key,
    required this.isFavorite,
    required this.onFavoritePressed,
    required this.onRatePressed,
    this.onSignUpPressed,
  });

  final bool isFavorite;
  final VoidCallback onFavoritePressed;

  /// null이면 평점 남기기 비활성화 (회원가입 전)
  final VoidCallback? onRatePressed;
  final VoidCallback? onSignUpPressed;

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onRatePressed == null) ...[
                _SignUpNotice(onSignUpPressed: onSignUpPressed),
                const SizedBox(height: 8),
              ],
              Row(
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
                        disabledBackgroundColor: AppColors.disabledButton,
                        disabledForegroundColor: AppColors.white,
                        textStyle: textStyle,
                        shape: shape,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// memberId 없을 때 안내 한 줄
class _SignUpNotice extends StatelessWidget {
  const _SignUpNotice({this.onSignUpPressed});

  final VoidCallback? onSignUpPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '학습용 회원가입 후 평점을 남길 수 있어요.',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        if (onSignUpPressed != null)
          TextButton(onPressed: onSignUpPressed, child: const Text('회원가입')),
      ],
    );
  }
}
