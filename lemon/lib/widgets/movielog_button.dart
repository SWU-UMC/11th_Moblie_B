import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 기본 · 통신 중 · 비활성 세 가지 상태를 표현하는 공용 버튼입니다.
/// 상태를 스스로 바꾸지 않고, 화면(ViewModel)이 넘겨준 값만 그립니다.
class MovieLogButton extends StatelessWidget {
  const MovieLogButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.width,
    this.height = 44,
    this.tonal = false,
    this.borderRadius = 12,
  });

  final String label;

  /// null이면 조건이 충족되지 않은 비활성 상태입니다.
  final VoidCallback? onPressed;

  /// true면 onPressed와 관계없이 비활성이고, 가운데에 인디케이터만 그립니다.
  final bool isLoading;

  /// null: 내용 기반 크기 · double.infinity: 부모가 허용하는 최대 너비 · 고정 값: 항상 같은 크기
  final double? width;
  final double height;

  /// true면 연한 보라 배경 + 보라 글자입니다. Dialog의 "취소"처럼 보조 동작에 씁니다.
  final bool tonal;

  /// 기본은 12입니다. Dialog 버튼처럼 알약 모양이 필요하면 높이의 절반을 줍니다.
  final double borderRadius;

  bool get _disabled => isLoading || onPressed == null;

  static const _horizontalPadding = 20.0;

  /// ElevatedButton의 기본 최소 너비입니다.
  static const _minWidth = 64.0;

  /// 테마의 labelLarge(앱 폰트·크기)를 그대로 쓰고 굵기만 바꿉니다.
  static TextStyle? _labelStyle(BuildContext context) =>
      Theme.of(context).textTheme.labelLarge
          ?.copyWith(fontWeight: FontWeight.bold);

  /// width가 null일 때 [label] 버튼이 차지할 너비입니다. 글자 크기 설정을 반영합니다.
  /// 버튼을 옆에 둘지 아래로 내릴지 정할 때 씁니다.
  static double contentWidth(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: _labelStyle(context)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width + _horizontalPadding * 2;
    painter.dispose();
    return math.max(width, _minWidth);
  }

  /// 보조(tonal) 버튼 배경색입니다.
  static const _tonalBackground = Color(0xFFEDE8F7);

  @override
  Widget build(BuildContext context) {
    final background = tonal ? _tonalBackground : AppColors.primary;
    final foreground = tonal ? AppColors.primary : AppColors.white;
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: _disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: tonal ? 0 : null,
          // 통신 중은 회색, 조건 미충족은 흐린 색으로 구분합니다.
          disabledBackgroundColor: isLoading
              ? AppColors.gray
              : background.withValues(alpha: 0.4),
          disabledForegroundColor: isLoading
              ? AppColors.white
              : foreground.withValues(alpha: tonal ? 0.5 : 1),
          padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
          textStyle: _labelStyle(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        // label과 인디케이터를 동시에 그리지 않고 하나만 그립니다.
        // 통신 중에도 label 자리는 비워 두어, 내용 기반 너비가 줄어들지 않게 합니다.
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
              Semantics(
                label: '$label 진행 중',
                child: const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
