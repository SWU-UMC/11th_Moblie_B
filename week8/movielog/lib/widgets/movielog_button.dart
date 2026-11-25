import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 버튼 색 종류 (Figma)
enum MovieLogButtonVariant {
  /// 보라 배경 + 흰 글자 (확인, 삭제 확정, 가입하기)
  primary,

  /// 연보라 배경 + 보라 글자 (취소, 카드 수정)
  tonal,

  /// 연빨강 배경 + 빨강 글자 (카드 삭제)
  danger,
}

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
    this.variant = MovieLogButtonVariant.primary,
    this.borderRadius = 12,
    this.fontSize,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? width;
  final double height;
  final MovieLogButtonVariant variant;

  /// 알약 모양은 height / 2
  final double borderRadius;

  /// null이면 labelLarge 그대로, 값 있으면 Bold로 그 크기
  final double? fontSize;

  bool get _disabled => isLoading || onPressed == null;

  (Color, Color) get _colors => switch (variant) {
    MovieLogButtonVariant.primary => (AppColors.violet, AppColors.white),
    MovieLogButtonVariant.tonal => (AppColors.tonalContainer, AppColors.violet),
    MovieLogButtonVariant.danger => (
      AppColors.dangerContainer,
      AppColors.error,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = _colors;
    final isPrimary = variant == MovieLogButtonVariant.primary;
    final baseStyle = Theme.of(context).textTheme.labelLarge;
    final size = fontSize;

    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: _disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: background,
          foregroundColor: foreground,
          // primary는 통신 중 회색, 나머지는 흐리게
          disabledBackgroundColor: isPrimary
              ? (isLoading ? AppColors.hint : AppColors.disabledButton)
              : background.withValues(alpha: 0.5),
          disabledForegroundColor: isPrimary
              ? AppColors.white
              : foreground.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          textStyle: size == null
              ? baseStyle
              : baseStyle?.copyWith(
                  fontSize: size,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  letterSpacing: 0,
                ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        // 로딩 중엔 인디케이터만 그림
        // 글자는 숨기기만 해서 버튼 너비가 안 줄어들게 함 (옆 입력창 안 흔들림)
        child: Stack(
          alignment: Alignment.center,
          children: [
            Visibility(
              visible: !isLoading,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: Text(label),
            ),
            if (isLoading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isPrimary ? AppColors.white : foreground,
                  semanticsLabel: '확인 중',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
