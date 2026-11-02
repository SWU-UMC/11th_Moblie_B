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
  });

  final String label;

  /// null이면 조건이 충족되지 않은 비활성 상태입니다.
  final VoidCallback? onPressed;

  /// true면 onPressed와 관계없이 비활성이고, 가운데에 인디케이터만 그립니다.
  final bool isLoading;

  /// null: 내용 기반 크기 · double.infinity: 부모가 허용하는 최대 너비 · 고정 값: 항상 같은 크기
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
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          // 통신 중은 회색, 조건 미충족은 흐린 보라색으로 구분합니다.
          disabledBackgroundColor: isLoading
              ? AppColors.gray
              : AppColors.primary.withValues(alpha: 0.4),
          disabledForegroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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
