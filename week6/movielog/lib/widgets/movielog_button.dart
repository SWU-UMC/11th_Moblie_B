import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 공용 버튼
/// 상태는 밖에서 받아서 그리기만 함
/// - 기본: onPressed 있음
/// - 통신 중: isLoading true → 비활성 + 인디케이터
/// - 비활성: onPressed null
///
/// width: null → 글자 길이, double.infinity → 부모 너비, 숫자 → 고정
class MovieLogButton extends StatelessWidget {
  const MovieLogButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.width,
    this.height = 44,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? width;
  final double height;

  bool get _disabled => isLoading || onPressed == null;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: _disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.violet,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: isLoading
              ? AppColors.hint
              : AppColors.disabledButton,
          disabledForegroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          textStyle: Theme.of(context).textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        // 로딩 중엔 인디케이터만 그림
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.white,
                  semanticsLabel: '확인 중',
                ),
              )
            : Text(label),
      ),
    );
  }
}
