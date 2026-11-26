import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_models/favorite_detail_view_model.dart';

/// 영화 상세의 제목·정보 오른쪽에 두는 북마크 버튼입니다.
///
/// 첫 여부 조회·등록·해제 중에는 북마크 자리에만 인디케이터를 그리고 누를 수 없습니다.
/// 결과는 서버 응답을 확인한 뒤 Snackbar로 안내합니다. 실패하면 이전 아이콘을 유지합니다.
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key});

  static const _size = Size(62, 64);

  Future<void> _toggle(BuildContext context, FavoriteDetailViewModel vm) async {
    final messenger = ScaffoldMessenger.of(context);
    await vm.toggle();
    // 요청 중 세션이 바뀌어 반영되지 않았다면(Router가 로그인으로 이동) 안내하지 않습니다.
    if (!context.mounted || vm.isDisposed || vm.isSaving) return;
    final message =
        vm.errorMessage ?? (vm.isFavorite ? '즐겨찾기에 추가했습니다.' : '즐겨찾기에서 삭제했습니다.');
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Consumer<FavoriteDetailViewModel>(
      builder: (context, vm, _) {
        final busy = vm.isLoading || vm.isSaving;
        final loadFailed = !vm.hasLoadedStatus && !vm.isLoading;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _size.width,
              height: _size.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.outlineVariant, width: 1.5),
              ),
              child: busy
                  ? Center(
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.primary,
                          semanticsLabel: '즐겨찾기 요청 중',
                        ),
                      ),
                    )
                  : loadFailed
                  // 첫 여부 조회에 실패했을 때만 같은 자리에 새로고침 버튼을 보여줍니다.
                  ? IconButton(
                      tooltip: '즐겨찾기 여부 다시 확인',
                      color: colors.primary,
                      onPressed: vm.load,
                      icon: const Icon(Icons.refresh),
                    )
                  : IconButton(
                      tooltip: vm.isFavorite ? '즐겨찾기 해제' : '즐겨찾기 등록',
                      color: colors.primary,
                      iconSize: 30,
                      onPressed: () => _toggle(context, vm),
                      icon: Icon(
                        vm.isFavorite ? Icons.bookmark : Icons.bookmark_border,
                      ),
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              '즐겨찾기',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      },
    );
  }
}
