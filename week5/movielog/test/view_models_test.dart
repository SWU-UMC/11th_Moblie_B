import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/data/movie_preferences.dart';
import 'package:movielog/models/movie_sort.dart';
import 'package:movielog/view_models/load_status.dart';
import 'package:movielog/view_models/movie_home_view_model.dart';
import 'package:movielog/view_models/movie_list_view_model.dart';
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

  group('MovieListViewModel', () {
    test('Discover를 page 1부터 불러 중복 없이 최대 30개를 만든다', () async {
      final service = FakeTmdbMovieService(overlapBetweenPages: true);
      final viewModel = MovieListViewModel(service);
      await viewModel.loadInitial();

      expect(viewModel.status, LoadStatus.success);
      expect(viewModel.genres, hasLength(3));
      expect(viewModel.movies, hasLength(30));
      expect(viewModel.movies.map((m) => m.id).toSet(), hasLength(30));
      expect(service.discoverCalls.map((c) => c.page), [1, 2]);
    });

    test('장르 결과가 30개보다 적으면 마지막 페이지까지만 요청하고 있는 만큼 보여준다', () async {
      final service = FakeTmdbMovieService();
      final viewModel = MovieListViewModel(service);
      await viewModel.loadInitial();
      service.discoverCalls.clear();

      await viewModel.selectGenres([878]); // SF: 5의 배수 9편

      expect(viewModel.movies, hasLength(9));
      // 9편이라 page 1(최대 20개)이 마지막 페이지 → 한 번만 요청
      expect(service.discoverCalls, hasLength(1));
      expect(service.discoverCalls.single.page, 1);
      expect(service.discoverCalls.single.genreIds, [878]);
    });

    test('장르를 고르면 with_genres로 page 1부터 다시 요청하고 선택을 저장한다', () async {
      final service = FakeTmdbMovieService();
      final viewModel = MovieListViewModel(service);
      await viewModel.loadInitial();
      service.discoverCalls.clear();

      await viewModel.selectGenres([28, 18]);

      expect(service.discoverCalls.first.page, 1);
      expect(service.discoverCalls.first.genreIds, [28, 18]);
      expect(viewModel.selectedGenreIds, [28, 18]);
      expect(await MoviePreferences().readGenreIds(), [28, 18]);

      await viewModel.selectGenres(const []);
      expect(service.discoverCalls.last.genreIds, isEmpty);
      expect(await MoviePreferences().readGenreIds(), isEmpty);
    });

    test('요청 중에는 장르를 바꿀 수 없다', () async {
      final service = FakeTmdbMovieService()..discoverGate = Completer();
      final viewModel = MovieListViewModel(service);
      final loading = viewModel.loadInitial();
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.status, LoadStatus.loading);
      expect(viewModel.canChangeGenres, isFalse);
      await viewModel.selectGenres([28]);
      expect(viewModel.selectedGenreIds, isEmpty);

      service.discoverGate!.complete();
      await loading;
      expect(viewModel.canChangeGenres, isTrue);
    });

    test('처음부터 실패하면 Error 상태, 다시 시도하면 성공한다', () async {
      final service = FakeTmdbMovieService()..failDiscover = true;
      final viewModel = MovieListViewModel(service);
      await viewModel.loadInitial();

      expect(viewModel.status, LoadStatus.error);
      expect(viewModel.message, isNotNull);
      expect(viewModel.retryDialogRequested, isFalse);

      service.failDiscover = false;
      await viewModel.retry();
      expect(viewModel.status, LoadStatus.success);
    });

    test('이전 목록이 있을 때 실패하면 목록을 유지하고 재시도 Dialog를 요청한다', () async {
      final service = FakeTmdbMovieService();
      final viewModel = MovieListViewModel(service);
      await viewModel.loadInitial();
      final before = viewModel.movies.map((m) => m.id).toList();

      service.failDiscover = true;
      await viewModel.refresh();

      expect(viewModel.status, LoadStatus.success);
      expect(viewModel.movies.map((m) => m.id), before);
      expect(viewModel.retryDialogRequested, isTrue);
      expect(viewModel.isRefreshing, isFalse);
    });

    test('장르 변경이 실패한 뒤 취소하면 마지막으로 성공한 장르로 되돌린다', () async {
      final service = FakeTmdbMovieService();
      final viewModel = MovieListViewModel(service);
      await viewModel.loadInitial();

      service.failDiscover = true;
      await viewModel.selectGenres([28]);
      expect(viewModel.retryDialogRequested, isTrue);

      viewModel.cancelRetry();
      expect(viewModel.selectedGenreIds, isEmpty);
      expect(viewModel.movies, hasLength(30));
    });

    test('늦게 도착한 이전 요청의 결과는 무시한다 (request version)', () async {
      final service = FakeTmdbMovieService();
      final viewModel = MovieListViewModel(service);

      // 첫 요청을 붙잡아 둔 채, 새 요청(다시 시도)이 먼저 성공하는 상황
      final gate = Completer<void>();
      service.discoverGate = gate;
      final firstRequest = viewModel.loadInitial();
      await pumpEventQueue();
      service.discoverGate = null;
      await viewModel.retry();
      expect(viewModel.status, LoadStatus.success);

      // 이제서야 첫 요청이 실패로 끝나도 화면 상태를 덮어쓰지 않습니다.
      service.failDiscover = true;
      gate.complete();
      await firstRequest;
      expect(viewModel.status, LoadStatus.success);
      expect(viewModel.retryDialogRequested, isFalse);
      expect(viewModel.movies, hasLength(30));
    });

    test('요청 중 화면이 사라지면(dispose) 늦게 온 응답으로 상태를 바꾸지 않는다', () async {
      final service = FakeTmdbMovieService();
      final viewModel = MovieListViewModel(service);
      final gate = Completer<void>();
      service.discoverGate = gate;

      final loading = viewModel.loadInitial();
      await pumpEventQueue();
      viewModel.dispose();
      gate.complete();

      // dispose 뒤 notifyListeners를 부르면 오류가 나므로, 끝까지 오류 없이 끝나야 합니다.
      await loading;
      expect(viewModel.movies, isEmpty);
    });

    test('저장된 장르와 정렬을 처음 불러올 때 복원한다', () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            MoviePreferences.selectedGenreIdsKey: ['878'],
            MoviePreferences.sortKey: MovieSort.title.name,
          });
      final service = FakeTmdbMovieService();
      final viewModel = MovieListViewModel(service);
      await viewModel.loadInitial();

      expect(viewModel.selectedGenreIds, [878]);
      expect(viewModel.sort, MovieSort.title);
      expect(service.discoverCalls.first.genreIds, [878]);
    });
  });
}
