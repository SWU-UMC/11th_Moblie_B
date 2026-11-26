import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../view_models/load_phase.dart';
import '../view_models/paged_movies_view_model.dart';
import '../widgets/movie_page_footer.dart';
import '../widgets/movie_row_card.dart';
import '../widgets/movielog_button.dart';

/// 영화 검색 화면입니다. (`/movies/search`, 하단 NavigationBar 없음)
///
/// 글자를 입력할 때마다 요청하지 않고, 제출했을 때만 page 1부터 검색합니다.
/// 빈 검색어는 서버에 보내지 않습니다. 영화 목록과는 별도의 [PagedMoviesViewModel]을 씁니다.
class MovieSearchScreen extends StatefulWidget {
  const MovieSearchScreen({super.key, required this.onOpenMovie});

  final Future<void> Function(TmdbMovieDto movie) onOpenMovie;

  @override
  State<MovieSearchScreen> createState() => _MovieSearchScreenState();
}

class _MovieSearchScreenState extends State<MovieSearchScreen> {
  final _text = TextEditingController();
  String _submittedQuery = '';
  String? _inputError;

  void _submitSearch(String value) {
    final query = value.trim();
    if (query.isEmpty) {
      setState(() => _inputError = '검색어를 입력해 주세요.');
      return;
    }
    setState(() {
      _inputError = null;
      _submittedQuery = query;
    });
    FocusScope.of(context).unfocus();
    context.read<PagedMoviesViewModel>().loadInitial(query: query);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          '영화 검색',
          style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _text,
              textInputAction: TextInputAction.search,
              onSubmitted: _submitSearch,
              decoration: InputDecoration(
                hintText: '영화 제목을 입력하세요',
                errorText: _inputError,
                filled: true,
                fillColor: colors.surfaceContainerLowest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.outlineVariant),
                ),
                suffixIcon: TextButton(
                  onPressed: () => _submitSearch(_text.text),
                  child: const Text('검색'),
                ),
              ),
            ),
          ),
          Expanded(
            child: Consumer<PagedMoviesViewModel>(
              builder: (context, vm, _) => _buildResults(context, vm),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context, PagedMoviesViewModel vm) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.bold,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    switch (vm.phase) {
      case LoadPhase.idle:
        return Center(child: Text('보고 싶은 영화를 검색해 보세요.', style: muted));
      case LoadPhase.loading:
        return const Center(child: CircularProgressIndicator());
      case LoadPhase.empty:
        return Center(child: Text('검색 결과가 없습니다.', style: muted));
      case LoadPhase.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(vm.errorMessage ?? '검색 결과를 불러오지 못했습니다.', style: muted),
              const SizedBox(height: 20),
              MovieLogButton(
                label: '다시 시도',
                width: 220,
                onPressed: () => vm.loadInitial(query: _submittedQuery),
              ),
            ],
          ),
        );
      case LoadPhase.ready:
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          itemCount: vm.movies.length + 1,
          separatorBuilder: (_, index) =>
              SizedBox(height: index == vm.movies.length - 1 ? 0 : 12),
          itemBuilder: (context, index) {
            if (index == vm.movies.length) {
              return MoviePageFooter(vm: vm, label: '검색 결과 더 보기');
            }
            final movie = vm.movies[index];
            return MovieRowCard(
              key: ValueKey(movie.id),
              movie: movie,
              fallbackTitle: movie.title,
              caption: [
                ?movie.releaseYear?.toString(),
                '★ ${movie.voteAverage.toStringAsFixed(1)}',
              ].join(' · '),
              onTap: () => widget.onOpenMovie(movie),
            );
          },
        );
    }
  }
}
