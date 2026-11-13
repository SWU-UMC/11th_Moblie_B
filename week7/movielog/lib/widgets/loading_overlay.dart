import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 화면 위 로딩 가림막 (다중 삭제 중)
/// 어두운 ModalBarrier + 가운데 흰 인디케이터만 (카드, 문구 없음)
/// 가림막이 터치를 다 먹어서 아래 화면 조작 안 됨
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
  });

  final bool isLoading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading) ...[
          const ModalBarrier(dismissible: false, color: AppColors.barrier),
          const Center(
            child: CircularProgressIndicator(
              color: AppColors.white,
              semanticsLabel: '삭제 중',
            ),
          ),
        ],
      ],
    );
  }
}
