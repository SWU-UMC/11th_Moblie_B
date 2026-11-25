import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../theme/app_colors.dart';
import '../view_models/load_phase.dart';
import '../view_models/paged_movies_view_model.dart';
import '../widgets/movie/movie_summary_card.dart';
import '../widgets/movie_page_footer.dart';
import '../widgets/movielog_button.dart';

/// W9 영화 검색 (/movies/search, 하단 바 없음)
/// 영화 목록이랑 다른 PagedMoviesViewModel 인스턴스 사용
/// - 제출(키보드 검색·검색 버튼): 바로 요청
/// - Challenge: 입력 멈추고 500ms 지나면 자동 요청 (debounce)
/// 빈 검색어는 서버에 안 보냄
class MovieSearchScreen extends StatefulWidget {
  const MovieSearchScreen({super.key, required this.onOpenMovie});

  final Future<void> Function(TmdbMovieDto movie) onOpenMovie;

  static const debounceDuration = Duration(milliseconds: 500);

  @override
  State<MovieSearchScreen> createState() => _MovieSearchScreenState();
}

class _MovieSearchScreenState extends State<MovieSearchScreen> {
  final _text = TextEditingController();
  Timer? _debounce;

  /// 마지막으로 요청한 검색어 (다시 시도할 때 씀)
  String _submittedQuery = '';
  String? _inputError;

  @override
  void dispose() {
    // 화면 나갔는데 대기 중인 타이머가 검색 보내지 않게
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  /// 제출: 기다리던 자동 검색 취소하고 바로 page 1
  void _submit(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() => _inputError = '검색어를 입력해 주세요.');
      return;
    }
    _search(query);
  }

  /// Challenge: 글자 바뀔 때마다 이전 타이머 취소 → 마지막 입력만 요청
  void _onChanged(String value) {
    if (_inputError != null) setState(() => _inputError = null);
    _debounce?.cancel();
    _debounce = Timer(MovieSearchScreen.debounceDuration, () {
      if (!mounted) return;
      final query = value.trim();
      // 빈 검색어, 이미 보여주는 검색어면 요청 안 함
      if (query.isEmpty || query == _submittedQuery) return;
      _search(query);
    });
  }

  void _search(String query) {
    setState(() {
      _inputError = null;
      _submittedQuery = query;
    });
    // 새 검색어 → 이전 결과 비우고 page 1 (늦게 온 이전 응답은 generation이 버림)
    context.read<PagedMoviesViewModel>().loadInitial(query: query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      appBar: AppBar(
        title: const Text(
          '영화 검색',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.violet,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.screenBackground,
        foregroundColor: AppColors.textPrimary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _SearchField(
              controller: _text,
              errorText: _inputError,
              onChanged: _onChanged,
              onSubmitted: _submit,
            ),
          ),
          Expanded(
            child: Consumer<PagedMoviesViewModel>(
              builder: (context, vm, _) => _SearchBody(
                vm: vm,
                onRetry: () => vm.loadInitial(query: _submittedQuery),
                onOpenMovie: widget.onOpenMovie,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.errorText,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  static OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color, width: 1.5),
  );

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('search-field'),
      controller: controller,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: '영화 제목을 입력해 주세요',
        hintStyle: const TextStyle(fontSize: 14, color: AppColors.hint),
        errorText: errorText,
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        enabledBorder: _border(AppColors.cardBorder),
        focusedBorder: _border(AppColors.violet),
        errorBorder: _border(AppColors.error),
        focusedErrorBorder: _border(AppColors.error),
        suffixIcon: TextButton(
          onPressed: () => onSubmitted(controller.text),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.violet,
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: const Text('검색'),
        ),
      ),
    );
  }
}

class _SearchBody extends StatelessWidget {
  const _SearchBody({
    required this.vm,
    required this.onRetry,
    required this.onOpenMovie,
  });

  final PagedMoviesViewModel vm;
  final VoidCallback onRetry;
  final Future<void> Function(TmdbMovieDto movie) onOpenMovie;

  static const _messageStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  @override
  Widget build(BuildContext context) {
    switch (vm.phase) {
      case LoadPhase.idle:
        return const Center(
          child: Text(
            '검색어를 입력해 주세요.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        );
      case LoadPhase.loading:
        return const Center(
          child: CircularProgressIndicator(
            color: AppColors.violet,
            semanticsLabel: '검색 중',
          ),
        );
      case LoadPhase.empty:
        return const Center(child: Text('검색 결과가 없습니다.', style: _messageStyle));
      case LoadPhase.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  vm.errorMessage ?? '검색 결과를 불러오지 못했습니다.',
                  textAlign: TextAlign.center,
                  style: _messageStyle,
                ),
                const SizedBox(height: 22),
                MovieLogButton(
                  label: '다시 시도',
                  width: 200,
                  borderRadius: 10,
                  fontSize: 14,
                  onPressed: onRetry,
                ),
              ],
            ),
          ),
        );
      case LoadPhase.ready:
        final movies = vm.movies;
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          // 마지막 칸은 더 보기 footer
          itemCount: movies.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            if (index == movies.length) return MoviePageFooter(vm: vm);
            final movie = movies[index];
            return MovieSummaryCard(
              key: ValueKey('search-${movie.id}'),
              movie: movie,
              title: movie.title,
              subtitle: movieSummaryLine(movie),
              tag: '상세 보기',
              onTap: () => onOpenMovie(movie),
            );
          },
        );
    }
  }
}
