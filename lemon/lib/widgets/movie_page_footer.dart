import 'package:flutter/material.dart';

import '../view_models/load_phase.dart';
import '../view_models/paged_movies_view_model.dart';
import 'movielog_button.dart';

/// 영화 목록·검색 결과 아래의 "더 보기 · 추가 로딩 · 다음 페이지 다시 시도 · 끝" 영역입니다.
class MoviePageFooter extends StatelessWidget {
  const MoviePageFooter({super.key, required this.vm, this.label = '더 보기'});

  final PagedMoviesViewModel vm;

  /// 기본 "더 보기"입니다. 검색 화면은 "검색 결과 더 보기"를 씁니다.
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (!vm.hasMore && !vm.isLoadingMore && vm.loadMoreError == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        child: Text(
          '모든 영화를 확인했습니다.',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
      );
    }

    final error = vm.loadMoreError;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        children: [
          if (error != null) ...[
            Text(
              error,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
          ],
          MovieLogButton(
            width: double.infinity,
            // 실패하면 같은 page를 다시 요청한다는 것을 문구로 알려줍니다.
            label: error == null ? label : '다음 페이지 다시 시도',
            isLoading: vm.isLoadingMore,
            onPressed: vm.phase == LoadPhase.ready ? vm.loadNextPage : null,
          ),
        ],
      ),
    );
  }
}
