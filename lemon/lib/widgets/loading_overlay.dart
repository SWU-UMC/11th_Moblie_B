import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// [isLoading]인 동안 화면 위에 어두운 막과 흰색 인디케이터만 올립니다.
/// 막이 터치를 모두 받아, 요청이 끝나기 전에 다른 동작을 할 수 없습니다.
/// 흰색 카드나 로딩 문구는 띄우지 않습니다.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.semanticsLabel = '처리 중',
  });

  final bool isLoading;
  final Widget child;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 막 뒤의 버튼을 키보드(Tab·Enter)로도 누를 수 없게 포커스를 막습니다.
        ExcludeFocus(excluding: isLoading, child: child),
        if (isLoading)
          const ModalBarrier(dismissible: false, color: Colors.black45),
        if (isLoading)
          Center(
            child: CircularProgressIndicator(
              color: AppColors.white,
              semanticsLabel: semanticsLabel,
            ),
          ),
      ],
    );
  }
}
