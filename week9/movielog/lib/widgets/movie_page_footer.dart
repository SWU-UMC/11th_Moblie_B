import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../view_models/load_phase.dart';
import '../view_models/paged_movies_view_model.dart';
import 'movielog_button.dart';

/// 목록 맨 아래: 더 보기 / 추가 로딩 / 다음 page 재시도 / 끝
/// (시각 자료 W9 영화 목록 4가지 상태)
class MoviePageFooter extends StatelessWidget {
  const MoviePageFooter({super.key, required this.vm});

  final PagedMoviesViewModel vm;

  static const _messageStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.textSecondary,
  );

  @override
  Widget build(BuildContext context) {
    final error = vm.loadMoreError;

    // 마지막 page까지 다 봄 → 더 보기 숨기고 끝 표시
    if (!vm.hasMore && !vm.isLoadingMore && error == null) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 24, 16, 32),
        child: Text(
          '모든 영화를 확인했습니다.',
          textAlign: TextAlign.center,
          style: _messageStyle,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (error != null) ...[
            Text(error, textAlign: TextAlign.center, style: _messageStyle),
            const SizedBox(height: 14),
          ],
          // 요청 중엔 버튼 비활성 + 인디케이터 (기존 카드는 그대로)
          MovieLogButton(
            key: const ValueKey('movie-page-footer-button'),
            width: double.infinity,
            borderRadius: 10,
            fontSize: 14,
            label: error == null ? '더 보기' : '다음 페이지 다시 시도',
            isLoading: vm.isLoadingMore,
            onPressed: vm.phase == LoadPhase.ready ? vm.loadNextPage : null,
          ),
        ],
      ),
    );
  }
}
