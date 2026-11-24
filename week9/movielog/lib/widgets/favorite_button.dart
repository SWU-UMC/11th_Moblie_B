import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../view_models/favorite_detail_view_model.dart';

/// 영화 상세 제목 오른쪽 북마크 (시각 자료 W9 상세: 등록 전/후/요청 중/실패)
/// 테두리 박스 안에 아이콘, 아래 "즐겨찾기" 글자
/// 결과는 서버 응답 받은 뒤 Snackbar로 안내
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key});

  static const double _boxSize = 52;

  Future<void> _toggle(BuildContext context, FavoriteDetailViewModel vm) async {
    await vm.toggle();
    if (!context.mounted || vm.isDisposed) return;
    final message =
        vm.errorMessage ?? (vm.isFavorite ? '즐겨찾기에 추가했습니다.' : '즐겨찾기에서 삭제했습니다.');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FavoriteDetailViewModel>();
    final busy = vm.isLoading || vm.isSaving;
    // 첫 여부 조회 실패 → 북마크 자리에 새로고침 (탭하면 다시 조회)
    final loadFailed = !vm.hasLoadedStatus && !vm.isLoading;

    final Widget icon;
    if (busy) {
      icon = const SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.violet,
          semanticsLabel: '즐겨찾기 요청 중',
        ),
      );
    } else if (loadFailed) {
      icon = const Icon(Icons.refresh, color: AppColors.violet);
    } else {
      icon = Icon(
        vm.isFavorite ? Icons.bookmark : Icons.bookmark_border,
        color: AppColors.violet,
        size: 26,
      );
    }

    final VoidCallback? onTap;
    if (busy) {
      onTap = null;
    } else if (loadFailed) {
      onTap = vm.load;
    } else {
      onTap = () => _toggle(context, vm);
    }

    final label = loadFailed
        ? '여부 다시 확인'
        : (vm.isFavorite ? '즐겨찾기 해제' : '즐겨찾기 추가');

    return Semantics(
      button: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.cardBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const ValueKey('favorite-button'),
              onTap: onTap,
              child: SizedBox.square(
                dimension: _boxSize,
                child: Center(child: icon),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '즐겨찾기',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.violet,
            ),
          ),
        ],
      ),
    );
  }
}
