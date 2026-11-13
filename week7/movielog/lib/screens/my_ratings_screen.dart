import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/rating_with_movie.dart';
import '../router/app_routes.dart';
import '../theme/app_colors.dart';
import '../view_models/load_status.dart';
import '../view_models/my_ratings_view_model.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/movie/rating_dialog.dart';
import '../widgets/movie_list/movie_list_empty.dart';
import '../widgets/movielog_button.dart';
import '../widgets/my_ratings/delete_rating_dialog.dart';
import '../widgets/tmdb_poster_image.dart';

// Figma: 제목 20 Bold 보라, 뒤로가기 검정, 배경 #FEFCF9
AppBar _myRatingsAppBar(BuildContext context) => AppBar(
  title: const Text('내가 등록한 평점', style: _MyRatingsText.appBarTitle),
  centerTitle: true,
  backgroundColor: AppColors.screenBackground,
  foregroundColor: AppColors.textPrimary,
);

/// Figma W7 프레임 글자 스타일 (Manrope, 줄 높이는 폰트 기본값)
abstract final class _MyRatingsText {
  static const appBarTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.violet,
  );
  static const cardTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
  static const score = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.violet,
  );
  static const comment = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// 편집, 취소, N개 선택됨
  static const header = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.violet,
  );
}

/// W7 내가 등록한 평점 (하단 바 없음)
/// 회원가입으로 받은 memberId로 조회·수정·삭제
class MyRatingsScreen extends StatelessWidget {
  const MyRatingsScreen({super.key});

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  /// 수정: 기존 별점·코멘트 채워서 Dialog 다시 엶
  Future<void> _onEditPressed(
    BuildContext context,
    RatingWithMovie entry,
  ) async {
    // Dialog는 root Navigator라 Provider 못 찾음 → 미리 꺼내 둠
    final viewModel = context.read<MyRatingsViewModel>();
    final rating = entry.rating;
    final saved = await RatingDialog.show(
      context,
      initialScore: rating.score,
      initialComment: rating.comment,
      onSubmit: (score, comment) => viewModel.updateRating(
        ratingId: rating.ratingId,
        score: score,
        comment: comment,
      ),
    );
    if (!context.mounted || saved != true) return;
    _showSnackBar(context, '평점을 수정했습니다.');
  }

  /// 단일 삭제: 삭제 끝날 때까지 Dialog 유지
  Future<void> _onDeletePressed(
    BuildContext context,
    RatingWithMovie entry,
  ) async {
    final viewModel = context.read<MyRatingsViewModel>();
    final deleted = await DeleteRatingDialog.show(
      context,
      onConfirm: () => viewModel.deleteRating(entry.rating.ratingId),
    );
    if (!context.mounted || deleted != true) return;
    _showSnackBar(context, '평점을 삭제했습니다.');
  }

  /// 다중 삭제: 확인만 받고 Dialog 닫은 뒤 화면 오버레이로 삭제
  Future<void> _onDeleteSelectedPressed(BuildContext context) async {
    final viewModel = context.read<MyRatingsViewModel>();
    final confirmed = await DeleteRatingDialog.show(
      context,
      title: '선택한 평점을 삭제할까요?',
    );
    if (confirmed != true || !context.mounted) return;

    final failed = await viewModel.deleteSelectedRatings();
    if (!context.mounted) return;
    _showSnackBar(
      context,
      failed > 0
          ? '$failed개 항목을 삭제하지 못했습니다. 선택된 항목을 다시 확인해 주세요.'
          : '선택한 평점을 삭제했습니다.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MyRatingsViewModel>();

    final body = switch (viewModel.status) {
      LoadStatus.idle || LoadStatus.loading => const Center(
        child: CircularProgressIndicator(color: AppColors.violet),
      ),
      // 저장은 됐는데 재조회만 실패했으면 그 문구로 안내 (조회만 다시)
      LoadStatus.error => _MyRatingsError(
        message:
            viewModel.refreshWarning ?? viewModel.message ?? '평점을 불러오지 못했습니다.',
        onRetry: viewModel.load,
      ),
      LoadStatus.empty => const MovieListEmpty(message: '아직 등록된 평점이 없어요.'),
      LoadStatus.success => _MyRatingsList(
        viewModel: viewModel,
        onEdit: (entry) => _onEditPressed(context, entry),
        onDelete: (entry) => _onDeletePressed(context, entry),
        onDeleteSelected: () => _onDeleteSelectedPressed(context),
      ),
    };

    // 다중 삭제 중엔 뒤로가기 막고, 가림막은 AppBar까지 덮음
    return PopScope(
      canPop: !viewModel.isDeletingSelected,
      child: LoadingOverlay(
        isLoading: viewModel.isDeletingSelected,
        child: Scaffold(
          backgroundColor: AppColors.screenBackground,
          appBar: _myRatingsAppBar(context),
          body: body,
        ),
      ),
    );
  }
}

class _MyRatingsList extends StatelessWidget {
  const _MyRatingsList({
    required this.viewModel,
    required this.onEdit,
    required this.onDelete,
    required this.onDeleteSelected,
  });

  final MyRatingsViewModel viewModel;
  final ValueChanged<RatingWithMovie> onEdit;
  final ValueChanged<RatingWithMovie> onDelete;
  final VoidCallback onDeleteSelected;

  @override
  Widget build(BuildContext context) {
    final notice = viewModel.message;
    final isEditing = viewModel.isEditing;
    final selectedCount = viewModel.selectedRatingIds.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 편집 전: 오른쪽 "편집"만 / 편집 중: 왼쪽 "N개 선택됨", 오른쪽 "취소"
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 35, 44, 0),
          child: Row(
            children: [
              Expanded(
                child: isEditing
                    ? Text('$selectedCount개 선택됨', style: _MyRatingsText.header)
                    : const SizedBox.shrink(),
              ),
              TextButton(
                onPressed: isEditing
                    ? viewModel.cancelEditing
                    : viewModel.startEditing,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(26, 19),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: AppColors.violet,
                  textStyle: _MyRatingsText.header,
                ),
                child: Text(isEditing ? '취소' : '편집'),
              ),
            ],
          ),
        ),
        if (notice != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Text(notice, style: _MyRatingsText.comment),
          ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(20, isEditing ? 25 : 21, 20, 24),
            itemCount: viewModel.ratings.length,
            separatorBuilder: (_, _) => SizedBox(height: isEditing ? 15 : 18),
            itemBuilder: (context, index) {
              final entry = viewModel.ratings[index];
              final ratingId = entry.rating.ratingId;
              return isEditing
                  ? SelectableRatingCard(
                      entry: entry,
                      selected: viewModel.selectedRatingIds.contains(ratingId),
                      onChanged: () => viewModel.toggleSelected(ratingId),
                    )
                  : RatingCard(
                      entry: entry,
                      onEdit: () => onEdit(entry),
                      onDelete: () => onDelete(entry),
                    );
            },
          ),
        ),
        if (isEditing)
          Padding(
            // Figma: 342 x 49 알약, 아래 여백 74
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 74),
            // 1개 이상 골라야 활성화
            child: MovieLogButton(
              label: '선택한 $selectedCount개 삭제',
              width: double.infinity,
              height: 49,
              borderRadius: 24.5,
              fontSize: 15,
              onPressed: selectedCount > 0 ? onDeleteSelected : null,
            ),
          ),
      ],
    );
  }
}

const _cardDecoration = BoxDecoration(
  color: AppColors.white,
  border: Border.fromBorderSide(
    BorderSide(color: AppColors.cardBorder, width: 2),
  ),
  borderRadius: BorderRadius.all(Radius.circular(16)),
);

/// 평점 카드 (Figma W7-REQ: 350 x 156, 포스터 82 x 124, 오른쪽 수정·삭제 63 x 35)
/// 본인 memberId로 조회한 목록이라 카드마다 수정·삭제 보여줌
class RatingCard extends StatelessWidget {
  const RatingCard({
    super.key,
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  final RatingWithMovie entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final rating = entry.rating;
    final movie = entry.movie;
    final comment = rating.comment;
    // 후기 없고 영화 정보도 없으면 후기 자리에 "포스터 정보 없음"
    final subText = (comment != null && comment.isNotEmpty)
        ? comment
        : (movie == null ? '포스터 정보 없음' : null);

    return Container(
      constraints: const BoxConstraints(minHeight: 156),
      // 테두리 2px이 여백에 더해져서 Figma 값(16, 17)에서 2씩 뺌
      padding: const EdgeInsets.fromLTRB(14, 14, 15, 14),
      decoration: _cardDecoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            // 영화 정보 없으면 Figma처럼 회색 사각형만
            child: movie == null
                ? Container(
                    width: 82,
                    height: 124,
                    color: AppColors.posterPlaceholder,
                  )
                : TmdbPosterImage(
                    posterPath: movie.posterPath,
                    width: 82,
                    height: 124,
                    size: 'w342',
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie?.title ?? '영화 #${rating.movieId}',
                    style: _MyRatingsText.cardTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Text('별점 ${rating.score} / 5', style: _MyRatingsText.score),
                  if (subText != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      subText,
                      style: _MyRatingsText.comment,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 9),
            child: Column(
              children: [
                MovieLogButton(
                  label: '수정',
                  width: 63,
                  height: 35,
                  borderRadius: 8,
                  fontSize: 13,
                  variant: MovieLogButtonVariant.tonal,
                  onPressed: onEdit,
                ),
                const SizedBox(height: 8),
                MovieLogButton(
                  label: '삭제',
                  width: 63,
                  height: 35,
                  borderRadius: 8,
                  fontSize: 13,
                  variant: MovieLogButtonVariant.danger,
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 편집 모드 카드 (Figma W7-CH 다중 선택: 350 x 128, 체크박스 25)
/// 수정·삭제 버튼 대신 CheckBox, 카드 아무 데나 눌러도 선택됨
class SelectableRatingCard extends StatelessWidget {
  const SelectableRatingCard({
    super.key,
    required this.entry,
    required this.selected,
    required this.onChanged,
  });

  final RatingWithMovie entry;
  final bool selected;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final rating = entry.rating;
    final comment = rating.comment;
    final title = entry.movie?.title ?? '영화 #${rating.movieId}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onChanged,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: _cardDecoration,
          child: Container(
            // Ink 테두리 2px이 바깥에 더해져서 Figma 값(128, 16, 28)에서 빼서 맞춤
            constraints: const BoxConstraints(minHeight: 124),
            padding: const EdgeInsets.fromLTRB(14, 26, 14, 26),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 19),
                  // 기본 Checkbox(18)를 Figma 크기 25로 키움
                  child: SizedBox.square(
                    dimension: 25,
                    child: Transform.scale(
                      scale: 25 / 18,
                      child: Checkbox(
                        value: selected,
                        onChanged: (_) => onChanged(),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        activeColor: AppColors.violet,
                        checkColor: AppColors.white,
                        side: const BorderSide(
                          color: AppColors.checkboxBorder,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(3),
                        ),
                        semanticLabel: '$title 선택',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 21),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$title · 별점 ${rating.score}',
                        style: _MyRatingsText.cardTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (comment != null && comment.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          comment,
                          style: _MyRatingsText.comment,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MyRatingsError extends StatelessWidget {
  const _MyRatingsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            // 고정 너비(120)
            MovieLogButton(label: '다시 시도', width: 120, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

/// 가입 안 해서 memberId 없을 때
class MyRatingsSignUpRequired extends StatelessWidget {
  const MyRatingsSignUpRequired({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      appBar: _myRatingsAppBar(context),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '학습용 회원가입이 필요합니다.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              MovieLogButton(
                label: '회원가입하기',
                onPressed: () => context.go(AppRoutes.register),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
