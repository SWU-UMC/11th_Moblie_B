import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/mock_movies.dart';
import '../models/movie.dart';
import '../services/fake_movie_service.dart';
import '../services/genre_preferences.dart';
import '../widgets/genre_filter_chips.dart';
import '../widgets/movie_empty_view.dart';
import '../widgets/movie_error_view.dart';
import '../widgets/movie_grid.dart';
import '../widgets/movie_loading_view.dart';
import '../widgets/movielog_app_bar.dart';

class MoviesScreen extends StatefulWidget {
  const MoviesScreen({super.key, this.movieService, this.genrePreferences});

  /// 테스트에서 결과 모드를 바꿀 수 있도록 주입받습니다. 없으면 기본 Service를 씁니다.
  final FakeMovieService? movieService;
  final GenrePreferences? genrePreferences;

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> {
  late final FakeMovieService _movieService;
  late final GenrePreferences _genrePreferences;
  String _selectedGenre = allGenresLabel;

  // 저장된 장르를 불러오는 동안 사용자가 고른 장르는 덮어쓰지 않습니다.
  bool _userSelectedGenre = false;

  // build는 여러 번 호출되므로 Future는 initState와 재시도에서만 만듭니다.
  late Future<List<Movie>> _moviesFuture;

  @override
  void initState() {
    super.initState();
    _movieService = widget.movieService ?? FakeMovieService();
    _genrePreferences = widget.genrePreferences ?? GenrePreferences();
    _moviesFuture = _movieService.fetchMovies();
    _restoreLastGenre();
  }

  Future<void> _restoreLastGenre() async {
    final String? saved;
    try {
      saved = await _genrePreferences.loadLastGenre();
    } catch (error) {
      // 읽기에 실패하면 기본 장르(전체)를 그대로 보여줍니다.
      debugPrint('마지막 장르 불러오기 실패: $error');
      return;
    }
    // await 사이에 화면이 사라졌을 수 있으므로 setState 전에 확인합니다.
    if (!mounted || _userSelectedGenre) return;
    if (saved == null || !movieGenres.contains(saved)) return;
    final genre = saved;
    setState(() => _selectedGenre = genre);
  }

  void _selectGenre(String genre) {
    _userSelectedGenre = true;
    setState(() => _selectedGenre = genre);
    _genrePreferences.saveLastGenre(genre);
  }

  void _retry() {
    // 화살표 함수로 쓰면 대입한 Future가 반환되어 setState가 오류를 냅니다.
    setState(() {
      _moviesFuture = _movieService.fetchMovies();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: MovieLogAppBar(
        title: '영화',
        titleColor: colors.primary,
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () {}, // 검색은 이후 과제에서 연결합니다.
            icon: SvgPicture.asset(
              'assets/icons/search.svg',
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(colors.onSurface, BlendMode.srcIn),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          GenreFilterChips(
            genres: movieGenres,
            selectedGenre: _selectedGenre,
            onSelected: _selectGenre,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<Movie>>(
              future: _moviesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const MovieLoadingView();
                }
                if (snapshot.hasError) {
                  // 원인은 개발자 로그로만 남기고, 화면에는 안내 문구만 보여줍니다.
                  debugPrint('영화 목록 로드 실패: ${snapshot.error}');
                  return MovieErrorView(onRetry: _retry);
                }

                final allMovies = snapshot.data ?? [];
                if (allMovies.isEmpty) {
                  return const MovieEmptyView(message: '아직 등록된 영화가 없어요.');
                }

                final movies = filterByGenre(allMovies, _selectedGenre);
                if (movies.isEmpty) {
                  return MovieEmptyView(
                    message: '$_selectedGenre 장르의 영화가 없어요.',
                    actionLabel: '전체 영화 보기',
                    onAction: () => _selectGenre(allGenresLabel),
                  );
                }
                return MovieGrid(movies: movies);
              },
            ),
          ),
        ],
      ),
    );
  }
}
