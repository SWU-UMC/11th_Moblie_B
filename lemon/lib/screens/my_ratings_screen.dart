import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/rating_dto.dart';
import '../data/models/rating_with_movie.dart';
import '../data/services/rating_api_service.dart';
import '../view_models/my_ratings_view_model.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/movie_empty_view.dart';
import '../widgets/movie_error_view.dart';
import '../widgets/movie_loading_view.dart';
import '../widgets/movielog_app_bar.dart';
import '../widgets/movielog_button.dart';
import '../widgets/rating_dialog.dart';
import '../widgets/tmdb_poster_image.dart';

/// 마이페이지 위에 열리는 "내가 등록한 평점" 화면입니다.
/// 조회 대상은 로그인한 본인이 아니라, 회원가입으로 받은 학습용 회원입니다.
class MyRatingsScreen extends StatelessWidget {
  const MyRatingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Consumer<MyRatingsViewModel>(
      builder: (context, viewModel, _) {
        final isSelecting = viewModel.isSelecting;
        final selectedCount = viewModel.selectedRatingIds.length;

        // 다중 삭제 중에는 뒤로 가기도 막고, 화면 전체를 오버레이로 덮습니다.
        return PopScope(
          canPop: !viewModel.isDeletingSelected,
          child: LoadingOverlay(
            isLoading: viewModel.isDeletingSelected,
            semanticsLabel: '선택한 평점 삭제 중',
            // bottomNavigationBar 자리에는 탭 대신 다중 삭제 버튼만 둡니다.
            child: Scaffold(
              appBar: MovieLogAppBar(
                title: '내가 등록한 평점',
                titleColor: colors.primary,
                leading: IconButton(
                  tooltip: '뒤로 가기',
                  onPressed: () => context.pop(),
                  icon: SvgPicture.asset(
                    'assets/icons/arrow_back.svg',
                    width: 24,
                    height: 24,
                    colorFilter: ColorFilter.mode(
                      colors.onSurface,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
              body: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isSelecting)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 12, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$selectedCount개 선택됨',
                                style: textTheme.titleMedium?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: viewModel.cancelSelection,
                              child: const Text('취소'),
                            ),
                          ],
                        ),
                      )
                    else
                      // 로그인한 사용자의 평점이라고 오해하지 않도록 조회 대상을 밝힙니다.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '학습용 회원(memberId ${viewModel.memberId})의 평점입니다.',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                            if (viewModel.status == MyRatingsLoadStatus.success)
                              TextButton(
                                onPressed: viewModel.startSelection,
                                child: const Text('선택 삭제'),
                              ),
                          ],
                        ),
                      ),
                    Expanded(child: _buildStatus(context, viewModel)),
                  ],
                ),
              ),
              bottomNavigationBar: isSelecting
                  ? SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        child: MovieLogButton(
                          label: '선택한 $selectedCount개 삭제',
                          width: double.infinity,
                          height: 56,
                          borderRadius: 28,
                          onPressed: selectedCount == 0
                              ? null
                              : () => _onDeleteSelectedPressed(context),
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatus(BuildContext context, MyRatingsViewModel viewModel) =>
      switch (viewModel.status) {
        MyRatingsLoadStatus.idle || MyRatingsLoadStatus.loading =>
          const MovieLoadingView(message: '평점을 불러오고 있어요'),
        MyRatingsLoadStatus.empty => MovieEmptyView(
          message: '아직 등록한 평점이 없어요.',
          actionLabel: '새로고침',
          onAction: viewModel.load,
        ),
        // 저장은 끝났고 GET만 실패했다면 그 사실을 먼저 알리고, 조회만 다시 시도합니다.
        MyRatingsLoadStatus.error => MovieErrorView(
          message: viewModel.refreshWarning ?? viewModel.message,
          onRetry: viewModel.load,
        ),
        MyRatingsLoadStatus.success => _RatingList(
          ratings: viewModel.ratings,
          notice: viewModel.message,
          onReload: viewModel.load,
          isSelecting: viewModel.isSelecting,
          selectedIds: viewModel.selectedRatingIds,
          onToggle: viewModel.toggleSelection,
          onEdit: (entry) => _onEditPressed(context, entry),
          onDelete: (rating) => _onDeletePressed(context, rating),
        ),
      };

  /// 기존 별점·코멘트를 채운 같은 RatingDialog로 수정합니다.
  /// Dialog 안에서 값을 바꾸는 동안 실제 rating은 건드리지 않으므로 취소해도 복구할 것이 없습니다.
  Future<void> _onEditPressed(
    BuildContext context,
    RatingWithMovie entry,
  ) async {
    final viewModel = context.read<MyRatingsViewModel>();
    final rating = entry.rating;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // 저장 중 바깥 탭으로 닫히는 것도 막습니다.
      builder: (_) => RatingDialog(
        initialScore: rating.score,
        initialComment: rating.comment, // null이면 빈 칸으로 시작합니다.
        movieTitle: entry.movie?.title ?? '영화 #${rating.movieId}',
        onSubmit: (score, comment) => viewModel.updateRating(
          ratingId: rating.ratingId,
          score: score,
          comment: comment,
        ),
      ),
    );

    if (!context.mounted || saved != true) return;
    _showSnackBar(context, '평점을 수정했습니다.');
  }

  /// 되돌릴 수 없는 삭제는 확인 Dialog 없이 실행하지 않습니다.
  Future<void> _onDeletePressed(BuildContext context, RatingDto rating) async {
    final viewModel = context.read<MyRatingsViewModel>();
    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // 삭제 중 바깥 탭으로 닫히는 것도 막습니다.
      builder: (_) => _DeleteRatingDialog(
        onConfirm: () => viewModel.deleteRating(rating.ratingId),
      ),
    );
    // deleted는 실제로 삭제까지 마쳤을 때만 true입니다. 취소는 요청을 보내지 않습니다.
    if (!context.mounted || deleted != true) return;
    _showSnackBar(context, '평점을 삭제했습니다.');
  }

  /// 확인 Dialog는 삭제 여부만 묻고 바로 닫힙니다.
  /// 삭제는 Dialog가 닫힌 뒤 화면의 ViewModel이 이어받고, 오버레이가 진행을 보여줍니다.
  Future<void> _onDeleteSelectedPressed(BuildContext context) async {
    final viewModel = context.read<MyRatingsViewModel>();
    final count = viewModel.selectedRatingIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _ConfirmDialog(
        title: '선택한 평점 $count개를 삭제할까요?',
        message: '삭제한 평점은 복구할 수 없습니다.',
        confirmLabel: '삭제',
        onCancel: () => Navigator.pop(dialogContext, false),
        onConfirm: () => Navigator.pop(dialogContext, true),
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final failed = await viewModel.deleteSelectedRatings();
    if (!context.mounted) return;
    _showSnackBar(
      context,
      failed == 0
          ? '평점 $count개를 삭제했습니다.'
          : '$failed개 항목을 삭제하지 못했습니다. 선택된 항목을 다시 확인해 주세요.',
    );
  }

  static void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }
}

class _RatingList extends StatelessWidget {
  const _RatingList({
    required this.ratings,
    required this.notice,
    required this.onReload,
    required this.isSelecting,
    required this.selectedIds,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final List<RatingWithMovie> ratings;

  /// 영화 정보를 일부 가져오지 못했을 때의 안내입니다. 없으면 null입니다.
  final String? notice;
  final VoidCallback onReload;
  final bool isSelecting;
  final Set<int> selectedIds;
  final ValueChanged<int> onToggle;
  final ValueChanged<RatingWithMovie> onEdit;
  final ValueChanged<RatingDto> onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final captionStyle = textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );

    final notice = this.notice;
    final hasNotice = notice != null && !isSelecting;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: ratings.length + (hasNotice ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        if (hasNotice && index == 0) {
          // 영화 조회가 일부 실패했다면 화면을 다시 열지 않고 바로 재시도할 수 있게 합니다.
          return Row(
            children: [
              Expanded(child: Text(notice, style: captionStyle)),
              TextButton(onPressed: onReload, child: const Text('다시 불러오기')),
            ],
          );
        }
        final entry = ratings[index - (hasNotice ? 1 : 0)];
        final ratingId = entry.rating.ratingId;
        if (isSelecting) {
          return _SelectableRatingCard(
            entry: entry,
            selected: selectedIds.contains(ratingId),
            onToggle: () => onToggle(ratingId),
          );
        }
        return _RatingCard(
          entry: entry,
          onEdit: () => onEdit(entry),
          onDelete: () => onDelete(entry.rating),
        );
      },
    );
  }
}

class _RatingCard extends StatelessWidget {
  const _RatingCard({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  final RatingWithMovie entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static const _posterWidth = 82.0;
  static const _posterHeight = 124.0;
  static const _editBackground = Color(0xFFEDE8F7);
  static const _deleteBackground = Color(0xFFFDEEEE);
  static const _deleteForeground = Color(0xFFB3261E);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final rating = entry.rating;
    final movie = entry.movie;
    final comment = rating.comment;
    final mutedStyle = textTheme.bodyMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final title = movie?.title ?? '영화 #${rating.movieId}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: movie == null
                // TMDB에서 영화를 찾지 못하면 포스터 자리만 비워 둡니다.
                ? Container(
                    width: _posterWidth,
                    height: _posterHeight,
                    color: colors.surfaceContainerHighest,
                  )
                : TmdbPosterImage(
                    posterPath: movie.posterPath,
                    width: _posterWidth,
                    height: _posterHeight,
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '별점 ${rating.score} / 5',
                    style: textTheme.titleSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (movie == null) ...[
                    const SizedBox(height: 8),
                    Text('포스터 정보 없음', style: mutedStyle),
                  ],
                  // 후기가 없으면(null) 표시하지 않습니다.
                  if (comment != null && comment.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(comment, style: mutedStyle),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '${_formatDate(rating.createdAt)} 등록',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 카드 오른쪽에 개별 수정·삭제 버튼을 세로로 둡니다.
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CardActionButton(
                  label: '수정',
                  semanticsLabel: '$title 평점 수정',
                  background: _editBackground,
                  foreground: colors.primary,
                  onPressed: onEdit,
                ),
                const SizedBox(height: 8),
                _CardActionButton(
                  label: '삭제',
                  semanticsLabel: '$title 평점 삭제',
                  background: _deleteBackground,
                  foreground: _deleteForeground,
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 서버 시각(UTC)을 기기 시간대로 바꿔 "2026.11.02" 형식으로 보여줍니다.
  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}.${two(local.month)}.${two(local.day)}';
  }
}

/// 평점 카드 오른쪽의 작은 수정·삭제 버튼입니다.
class _CardActionButton extends StatelessWidget {
  const _CardActionButton({
    required this.label,
    required this.semanticsLabel,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final String label;
  final String semanticsLabel;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      button: true,
      excludeSemantics: true,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          minimumSize: const Size(64, 36),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          textStyle: Theme.of(context).textTheme.labelLarge
              ?.copyWith(fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

/// 다중 삭제 모드의 카드입니다. 카드 어디를 눌러도 선택이 바뀝니다.
class _SelectableRatingCard extends StatelessWidget {
  const _SelectableRatingCard({
    required this.entry,
    required this.selected,
    required this.onToggle,
  });

  final RatingWithMovie entry;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final rating = entry.rating;
    final comment = rating.comment;
    final title = entry.movie?.title ?? '영화 #${rating.movieId}';
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(
        color: selected ? colors.primary : colors.outlineVariant,
        width: 1.5,
      ),
    );

    return Material(
      color: colors.surfaceContainerLowest,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 24, 20, 24),
          child: Row(
            children: [
              Checkbox(value: selected, onChanged: (_) => onToggle()),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$title · 별점 ${rating.score}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (comment != null && comment.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        comment,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 평점 Dialog와 같은 모양의 확인 Dialog입니다.
class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
    this.isLoading = false,
    this.errorText,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final bool isLoading;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final errorText = this.errorText;

    return AlertDialog(
      backgroundColor: colors.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      contentPadding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            if (errorText != null) ...[
              const SizedBox(height: 12),
              Text(
                errorText,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(color: colors.error),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: MovieLogButton(
                    label: '취소',
                    tonal: true,
                    height: 48,
                    borderRadius: 24,
                    width: double.infinity,
                    onPressed: onCancel,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: MovieLogButton(
                    label: confirmLabel,
                    height: 48,
                    borderRadius: 24,
                    width: double.infinity,
                    isLoading: isLoading,
                    onPressed: onConfirm,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 평점 한 건 삭제 확인 Dialog입니다.
/// 삭제 요청 중에는 Dialog가 닫히지 않고, 실패하면 Dialog 안에서 안내한 뒤 다시 시도할 수 있습니다.
class _DeleteRatingDialog extends StatefulWidget {
  const _DeleteRatingDialog({required this.onConfirm});

  final Future<void> Function() onConfirm;

  @override
  State<_DeleteRatingDialog> createState() => _DeleteRatingDialogState();
}

class _DeleteRatingDialogState extends State<_DeleteRatingDialog> {
  bool _isDeleting = false;
  String? _errorText;

  Future<void> _onConfirm() async {
    setState(() {
      _isDeleting = true;
      _errorText = null;
    });
    try {
      await widget.onConfirm();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
        _errorText = error is RatingWriteFailure
            ? error.message
            : '삭제하지 못했습니다. 잠시 후 다시 시도해 주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDeleting,
      child: _ConfirmDialog(
        title: '평점을 삭제할까요?',
        message: '삭제한 평점은 복구할 수 없습니다.',
        confirmLabel: '삭제',
        isLoading: _isDeleting,
        errorText: _errorText,
        // 취소는 onConfirm을 부르지 않으므로 삭제 요청을 보내지 않습니다.
        onCancel: _isDeleting ? null : () => Navigator.pop(context, false),
        onConfirm: _isDeleting ? null : _onConfirm,
      ),
    );
  }
}
