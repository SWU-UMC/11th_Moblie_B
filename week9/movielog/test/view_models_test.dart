import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/data/movie_preferences.dart';
import 'package:movielog/models/movie_sort.dart';
import 'package:movielog/view_models/load_phase.dart';
import 'package:movielog/view_models/load_status.dart';
import 'package:movielog/view_models/movie_home_view_model.dart';
import 'package:movielog/view_models/movie_list_view_model.dart';
import 'package:movielog/view_models/paged_movies_view_model.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_tmdb_movie_service.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('MovieHomeViewModel', () {
    test('Popular 결과에서 앞 5개만 쓴다', () async {
      final viewModel = MovieHomeViewModel(FakeTmdbMovieService());
      await viewModel.loadPopular();

      expect(viewModel.status, LoadStatus.success);
      expect(viewModel.popularMovies.map((m) => m.id), [1, 2, 3, 4, 5]);
      expect(viewModel.featuredMovie?.id, 1);
    });

    test('결과가 5개보다 적어도 RangeError 없이 있는 만큼만 쓴다', () async {
      final viewModel = MovieHomeViewModel(
        FakeTmdbMovieService(popularCount: 3),
      );
      await viewModel.loadPopular();

      expect(viewModel.popularMovies, hasLength(3));
    });

    test('요청이 실패하면 Error 상태와 안내 문구', () async {
      final service = FakeTmdbMovieService()..failPopular = true;
      final viewModel = MovieHomeViewModel(service);
      await viewModel.loadPopular();

      expect(viewModel.status, LoadStatus.error);
      expect(viewModel.message, '인기 영화를 불러오지 못했어요.');
    });
  });

  group('MovieListViewModel (9주차: 필터만, 목록은 PagedMoviesViewModel)', () {
    MovieListViewModel create(FakeTmdbMovieService service) =>
        MovieListViewModel(service, PagedMoviesViewModel(tmdbApi: service));

    test('처음 진입: 장르 목록 + Discover 첫 page만 (30개 수집 안 함)', () async {
      final service = FakeTmdbMovieService();
      final viewModel = create(service);
      await viewModel.loadInitial();

      expect(viewModel.paged.phase, LoadPhase.ready);
      expect(viewModel.genres, hasLength(3));
      expect(viewModel.movies, hasLength(20));
      expect(service.discoverCalls.map((c) => c.page), [1]);
    });

    test('장르를 고르면 with_genres로 page 1부터 다시 요청하고 선택을 저장한다', () async {
      final service = FakeTmdbMovieService();
      final viewModel = create(service);
      await viewModel.loadInitial();
      service.discoverCalls.clear();

      await viewModel.selectGenres([28, 18]);

      expect(service.discoverCalls.single.page, 1);
      expect(service.discoverCalls.single.genreIds, [28, 18]);
      expect(viewModel.selectedGenreIds, [28, 18]);
      expect(await MoviePreferences().readGenreIds(), [28, 18]);

      await viewModel.selectGenres(const []);
      expect(service.discoverCalls.last.genreIds, isEmpty);
      expect(await MoviePreferences().readGenreIds(), isEmpty);
    });

    test('장르 목록이 실패해도 영화 목록은 보여준다 (Chip만 없음)', () async {
      final service = FakeTmdbMovieService()..failGenres = true;
      final viewModel = create(service);
      await viewModel.loadInitial();

      expect(viewModel.genres, isEmpty);
      expect(viewModel.paged.phase, LoadPhase.ready);
    });

    test('저장된 장르와 정렬을 처음 불러올 때 복원한다', () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            MoviePreferences.selectedGenreIdsKey: ['878'],
            MoviePreferences.sortKey: MovieSort.title.name,
          });
      final service = FakeTmdbMovieService();
      final viewModel = create(service);
      await viewModel.loadInitial();

      expect(viewModel.selectedGenreIds, [878]);
      expect(viewModel.sort, MovieSort.title);
      expect(service.discoverCalls.first.genreIds, [878]);
    });
  });
}
