import 'package:dio/dio.dart';

import '../data/services/rating_api_service.dart';
import '../data/models/rating_dto.dart';
import '../view_models/auth_view_model.dart';
import '../widgets/rating_dialog.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_models/my_ratings_view_model.dart';
import '../widgets/tmdb_poster_image.dart';
import '../widgets/movielog_button.dart';

class MyRatingsScreen extends StatelessWidget {
  const MyRatingsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const BackButton(),
      centerTitle: true,
      title: const Text('내가 등록한 평점'),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('이번 로그인에서 등록한 평점입니다. 앱을 다시 시작하면 이전 평점 목록은 복원되지 않습니다.'),
        ),
        Expanded(
          child: Consumer<MyRatingsViewModel>(
            builder: (context, vm, child) {
              return switch (vm.status) {
                MyRatingsLoadStatus.idle || MyRatingsLoadStatus.loading =>
                  const Center(child: CircularProgressIndicator()),
                MyRatingsLoadStatus.empty => const Center(
                  child: Text('아직 등록된 평점이 없습니다.'),
                ),
                MyRatingsLoadStatus.error => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (vm.refreshWarning != null) Text(vm.refreshWarning!),
                        Text(vm.message ?? '평점을 불러오지 못했습니다.'),
                        const SizedBox(height: 16),
                        MovieLogButton(
                          label: '조회 재시도',
                          width: 120,
                          onPressed: vm.load,
                        ),
                      ],
                    ),
                  ),
                ),
                MyRatingsLoadStatus.success => ListView(
                  children: [
                    if (vm.message != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(vm.message!),
                      ),
                    ...vm.ratings.map(
                      (entry) => Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TmdbPosterImage(
                                posterPath: entry.movie?.posterPath,
                                width: 80,
                                height: 120,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.movie?.title ??
                                          '영화 #${entry.rating.movieId}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    Text('영화 ID: ${entry.rating.movieId}'),
                                    Text('★ ${entry.rating.score} / 5'),
                                    if (entry.rating.comment != null)
                                      Text(entry.rating.comment!),
                                    Text(
                                      '등록일: ${entry.rating.createdAt.toLocal().toIso8601String().substring(0, 10)}',
                                    ),
                                  ],
                                ),
                              ),
                              if (context.watch<AuthViewModel>().status ==
                                  AuthStatus.signedIn)
                                Column(
                                  children: [
                                    TextButton(
                                      onPressed: vm.isWriting
                                          ? null
                                          : () => onEditPressed(
                                              context,
                                              entry.rating,
                                            ),
                                      child: const Text('수정'),
                                    ),
                                    TextButton(
                                      onPressed: vm.isWriting
                                          ? null
                                          : () => onDeletePressed(
                                              context,
                                              entry.rating,
                                            ),
                                      child: const Text(
                                        '삭제',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              };
            },
          ),
        ),
      ],
    ),
  );
}

Future<void> onEditPressed(BuildContext context, RatingDto rating) async {
  final vm = context.read<MyRatingsViewModel>();
  await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => RatingDialog(
      initialScore: rating.score,
      initialComment: rating.comment,
      onSubmit: (score, comment) => vm.updateRating(
        ratingId: rating.ratingId,
        score: score,
        comment: comment,
      ),
    ),
  );
}

Future<void> onDeletePressed(BuildContext context, RatingDto rating) async {
  final vm = context.read<MyRatingsViewModel>();
  await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _DeleteRatingDialog(onConfirm: () => vm.deleteRating(rating.ratingId)),
  );
}

class _DeleteRatingDialog extends StatefulWidget {
  const _DeleteRatingDialog({required this.onConfirm});
  final Future<void> Function() onConfirm;
  @override
  State<_DeleteRatingDialog> createState() => _DeleteRatingDialogState();
}

class _DeleteRatingDialogState extends State<_DeleteRatingDialog> {
  bool _isDeleting = false;
  String? _errorText;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_isDeleting,
    child: AlertDialog(
      title: const Text('평점을 삭제할까요?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('삭제한 평점은 복구할 수 없습니다.'),
          if (_errorText != null)
            Text(_errorText!, style: const TextStyle(color: Colors.red)),
        ],
      ),
      actions: [
        MovieLogButton(
          label: '취소',
          onPressed: _isDeleting ? null : () => Navigator.pop(context, false),
        ),
        MovieLogButton(
          label: '삭제',
          isLoading: _isDeleting,
          onPressed: _isDeleting ? null : _onConfirm,
        ),
      ],
    ),
  );
  Future<void> _onConfirm() async {
    if (_isDeleting) return;
    setState(() {
      _isDeleting = true;
      _errorText = null;
    });
    try {
      await widget.onConfirm();
      if (!mounted) return;
      setState(() => _isDeleting = false);
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      final message = error is DioException
          ? writeErrorMessage(error)
          : '삭제하지 못했습니다. 목록을 확인한 뒤 다시 시도해 주세요.';
      setState(() {
        _isDeleting = false;
        _errorText = message;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
