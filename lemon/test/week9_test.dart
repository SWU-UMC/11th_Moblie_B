import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:movielog/core/network/auth_interceptor.dart';
import 'package:movielog/core/session/auth_session_bridge.dart';
import 'package:movielog/core/session/session_guard.dart';
import 'package:movielog/core/utils/map_bounded.dart';
import 'package:movielog/data/models/favorite_check_dto.dart';
import 'package:movielog/data/models/favorite_response_dto.dart';
import 'package:movielog/data/models/login_models.dart';
import 'package:movielog/data/models/member_info.dart';
import 'package:movielog/data/models/tmdb_genre_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page.dart';
import 'package:movielog/data/services/favorite_api_service.dart';
import 'package:movielog/view_models/favorite_detail_view_model.dart';
import 'package:movielog/view_models/load_phase.dart';
import 'package:movielog/view_models/paged_movies_view_model.dart';
import 'package:movielog/widgets/movie_card.dart';
import 'package:movielog/widgets/movie_row_card.dart';
import 'package:movielog/widgets/movielog_button.dart';

import 'fakes/movie_log_fakes.dart';

/// page·검색어·장르별로 정해진 결과를 돌려주고, 응답 시점을 테스트가 정할 수 있는 TMDB Service입니다.
class _PagedTmdbService extends FakeMovieLookupService {
  _PagedTmdbService({super.movies, super.failingIds, this.totalPages = 3});

  final int totalPages;
  final int perPage = 4;

  /// (page, genreId, query) 순서대로 기록합니다.
  final calls = <(int, int?, String)>[];

  /// 이 page들은 한 번 실패합니다. (같은 page 재시도 확인용)
  final failOnce = <int>{};

  /// 값을 넣으면 해당 조건의 응답을 Completer가 끝날 때까지 미룹니다.
  final gates = <String, Completer<void>>{};

  /// 검색 결과가 없는 검색어입니다.
  final emptyQueries = <String>{};

  TmdbMoviePageDto _build(int page, String prefix, int seed) =>
      TmdbMoviePageDto(
        page: page,
        results: [
          for (var i = 0; i < perPage; i++)
            fakeMovie(seed + (page - 1) * perPage + i, '$prefix ${page}p-$i'),
          // 앞 page의 마지막 영화가 다시 와도 한 번만 보여야 합니다.
          if (page > 1) fakeMovie(seed + (page - 1) * perPage - 1, '중복'),
        ],
        totalPages: totalPages,
        totalResults: totalPages * perPage,
      );

  Future<void> _wait(String key) async {
    final gate = gates[key];
    if (gate != null) await gate.future;
  }

  @override
  Future<TmdbMoviePageDto> discoverMovies({
    required int page,
    int? genreId,
  }) async {
    calls.add((page, genreId, ''));
    await _wait('genre:$genreId');
    if (failOnce.remove(page)) throw fakeDioError('/discover/movie');
    return _build(page, genreId == null ? '전체' : '장르$genreId', 1000);
  }

  @override
  Future<TmdbMoviePageDto> searchMovies({
    required int page,
    required String query,
  }) async {
    calls.add((page, null, query));
    await _wait('query:$query');
    if (emptyQueries.contains(query)) {
      return const TmdbMoviePageDto(
        page: 1,
        results: [],
        totalPages: 0,
        totalResults: 0,
      );
    }
    return _build(page, query, 5000);
  }

  @override
  Future<List<TmdbGenreDto>> fetchGenres() async => const [
    TmdbGenreDto(id: 18, name: '드라마'),
    TmdbGenreDto(id: 10749, name: '로맨스'),
  ];
}

const _otherMember = (email: 'other@example.com', nickname: '다른계정');

void main() {
  setUpAll(() => dotenv.loadFromString(envString: 'TMDB_ACCESS_TOKEN=test'));
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  void useTallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<TestApp> pumpApp(
    WidgetTester tester,
    TestApp app, {
    String initialLocation = '/start',
  }) async {
    useTallScreen(tester);
    await tester.pumpWidget(app.build(initialLocation: initialLocation));
    await tester.pumpAndSettle();
    return app;
  }

  Finder gridScrollable() => find.descendant(
    of: find.byType(CustomScrollView),
    matching: find.byType(Scrollable),
  );
  Finder bookmarkButton() => find.byTooltip('즐겨찾기 등록');
  Finder unbookmarkButton() => find.byTooltip('즐겨찾기 해제');

  group('Network and models', () {
    test('JWT goes only to v8 favorites with the allowed methods', () {
      bool protectedFor(String method, String path, {String? host}) =>
          AuthInterceptor.isProtected(
            RequestOptions(
              method: method,
              baseUrl: host ?? 'https://workbook.devnoco.com',
              path: path,
            ),
          );

      expect(protectedFor('POST', '/v8/favorites'), isTrue);
      expect(protectedFor('GET', '/v8/favorites'), isTrue);
      expect(protectedFor('GET', '/v8/favorites/550'), isTrue);
      expect(protectedFor('DELETE', '/v8/favorites/550'), isTrue);
      expect(protectedFor('GET', '/v8/members/me'), isTrue);
      expect(protectedFor('POST', '/v8/movie-records'), isTrue);
      // 허용되지 않은 method·경로, 공개 API, 이전 버전, 다른 host에는 붙이지 않습니다.
      expect(protectedFor('DELETE', '/v8/favorites'), isFalse);
      expect(protectedFor('POST', '/v8/favorites/550'), isFalse);
      expect(protectedFor('GET', '/v8/favorites/0'), isFalse);
      expect(protectedFor('GET', '/v8/favorites/abc'), isFalse);
      expect(protectedFor('POST', '/v8/auth/login'), isFalse);
      expect(protectedFor('GET', '/v7/members/me'), isFalse);
      expect(
        protectedFor(
          'GET',
          '/v8/favorites',
          host: 'https://api.themoviedb.org/3',
        ),
        isFalse,
      );
    });

    test('FavoriteApiService uses movieId paths and wrapper results', () async {
      final adapter = _JsonAdapter((options) {
        final path = options.uri.path;
        return switch ((options.method, path)) {
          ('POST', '/v8/favorites') => (
            201,
            {
              'isSuccess': true,
              'code': 'COMMON201',
              'message': '등록',
              'result': {
                'favoriteId': 3,
                'movieId': 550,
                'createdAt': '2026-09-06T12:14:03.000Z',
              },
            },
          ),
          ('GET', '/v8/favorites') => (
            200,
            {
              'isSuccess': true,
              'code': 'COMMON200',
              'message': '조회',
              'result': <Object>[],
            },
          ),
          ('GET', '/v8/favorites/550') => (
            200,
            {
              'isSuccess': true,
              'code': 'COMMON200',
              'message': '여부',
              'result': {'isFavorite': true},
            },
          ),
          // 해제는 평점 삭제와 달리 200 + result null입니다.
          ('DELETE', '/v8/favorites/550') => (
            200,
            {
              'isSuccess': true,
              'code': 'COMMON200',
              'message': '해제',
              'result': null,
            },
          ),
          _ => (404, {'isSuccess': false, 'code': 'X', 'message': 'x'}),
        };
      });
      final service = FavoriteApiService(
        Dio(BaseOptions(baseUrl: 'https://workbook.devnoco.com'))
          ..httpClientAdapter = adapter,
      );

      final added = await service.addFavorite(movieId: 550);
      expect((added.favoriteId, added.movieId), (3, 550));
      expect(added.createdAt, DateTime.utc(2026, 9, 6, 12, 14, 3));
      expect(await service.fetchMyFavorites(), isEmpty);
      final check = await service.checkFavorite(movieId: 550);
      expect((check.movieId, check.isFavorite), (550, true));
      await service.deleteFavorite(movieId: 550);

      expect(adapter.requests, [
        'POST /v8/favorites {"movieId":550}',
        'GET /v8/favorites',
        'GET /v8/favorites/550',
        'DELETE /v8/favorites/550',
      ]);
    });

    test('FavoriteCheckDto rejects a non-boolean isFavorite', () {
      expect(
        () => FavoriteCheckDto.fromJson({'isFavorite': 'yes'}, movieId: 1),
        throwsFormatException,
      );
      expect(
        () => FavoriteResponseDto.fromJson(const ['x']),
        throwsFormatException,
      );
    });

    test('mapBounded keeps order and runs at most N at once', () async {
      var running = 0;
      var peak = 0;
      final result = await mapBounded(List.generate(12, (i) => i), 5, (
        value,
      ) async {
        running++;
        peak = running > peak ? running : peak;
        await Future<void>.delayed(Duration(milliseconds: 12 - value));
        running--;
        return value * 10;
      });
      expect(result, List.generate(12, (i) => i * 10));
      expect(peak, 5);
      expect(await mapBounded(<int>[], 5, (v) async => v), isEmpty);
    });
  });

  group('Session guard', () {
    test('bridge starts a session per login, not per nickname change', () {
      final signals = ChangeNotifier();
      var version = 1;
      String? email;
      final bridge = AuthSessionBridge(
        authSignals: signals,
        sessionVersion: () => version,
        verifiedEmail: () => email,
      );
      addTearDown(bridge.dispose);
      final guard = bridge.guard;
      expect(guard.accountId, isNull);

      email = 'a@example.com';
      signals.notifyListeners();
      final first = guard.generation;
      expect(guard.isCurrent(first, 'a@example.com'), isTrue);

      // 닉네임 수정처럼 버전·email이 그대로면 새 세션이 아닙니다.
      signals.notifyListeners();
      expect(guard.generation, first);

      // 같은 email로 다시 로그인해도 sessionVersion이 바뀌면 새 세션입니다.
      version = 2;
      signals.notifyListeners();
      expect(guard.isCurrent(first, 'a@example.com'), isFalse);
      expect(guard.accountId, 'a@example.com');

      // 로그아웃: 계정이 비고, 이전 세션 응답은 모두 버립니다.
      version = 3;
      email = null;
      signals.notifyListeners();
      expect(guard.accountId, isNull);
    });

    test('SessionGuard rejects another account or generation', () {
      final guard = SessionGuard();
      final g = guard.startSession('a@example.com');
      expect(guard.isCurrent(g, 'a@example.com'), isTrue);
      expect(guard.isCurrent(g, 'b@example.com'), isFalse);
      guard.invalidate();
      expect(guard.isCurrent(g, 'a@example.com'), isFalse);
    });
  });

  group('FavoriteDetailViewModel', () {
    late FakeFavoriteApiService api;
    late SessionGuard guard;
    late int expireCalls;

    FavoriteDetailViewModel create() {
      final vm = FavoriteDetailViewModel(
        movieId: 550,
        favoriteApi: api,
        sessionGuard: guard,
        accountId: 'movie@example.com',
        onSessionExpired: () async => expireCalls++,
      );
      addTearDown(vm.dispose);
      return vm;
    }

    setUp(() {
      api = FakeFavoriteApiService();
      guard = SessionGuard()..startSession('movie@example.com');
      expireCalls = 0;
    });

    test('load then add and delete only after the server succeeds', () async {
      final vm = create();
      await vm.load();
      expect((vm.hasLoadedStatus, vm.isFavorite), (true, false));

      final gate = Completer<void>();
      api.onAdd = (movieId) async {
        await gate.future;
        return FavoriteResponseDto(
          favoriteId: 1,
          movieId: movieId,
          createdAt: DateTime.utc(2026),
        );
      };
      final saving = vm.toggle();
      // 결과 전에는 아이콘을 바꾸지 않습니다. (optimistic update 없음)
      expect((vm.isSaving, vm.isFavorite), (true, false));
      await vm.toggle(); // 요청 중 중복 탭은 무시합니다.
      gate.complete();
      await saving;
      expect((vm.isSaving, vm.isFavorite), (false, true));

      api.onAdd = null;
      api.seed('movie@example.com', [550]); // 서버에 등록된 상태
      await vm.toggle();
      expect(vm.isFavorite, isFalse);
      expect(api.log, ['GET 550', 'POST 550', 'DELETE 550']);
    });

    test('409 and 404 resync with GET instead of repeating', () async {
      final vm = create();
      await vm.load();
      // 다른 기기에서 먼저 등록된 상황입니다.
      api.seed('movie@example.com', [550]);
      await vm.toggle();
      expect(vm.isFavorite, isTrue);
      expect(vm.errorMessage, isNull);
      expect(api.log, ['GET 550', 'POST 550', 'GET 550']);

      // 다른 기기에서 먼저 해제된 상황입니다.
      api.store['movie@example.com']!.clear();
      api.log.clear();
      await vm.toggle();
      expect(vm.isFavorite, isFalse);
      expect(api.log, ['DELETE 550', 'GET 550']);
    });

    test('network failure keeps the previous state', () async {
      final vm = create();
      await vm.load();
      api.onAdd = (_) async => throw fakeDioError('/v8/favorites');
      await vm.toggle();
      expect(vm.isFavorite, isFalse);
      expect(vm.errorMessage, '즐겨찾기 등록에 실패했습니다.');
      expect(expireCalls, 0);
    });

    test('403 does not log out; AUTH401_3 expires the session', () async {
      final vm = create();
      await vm.load();
      api.onAdd = (_) async =>
          throw fakeCommonError('/v8/favorites', 403, 'COMMON403', '권한 없음');
      await vm.toggle();
      expect(expireCalls, 0);

      api.onAdd = (_) async => throw fakeInvalidToken('/v8/favorites');
      await vm.toggle();
      expect(expireCalls, 1);
    });

    test('a response after a session change is ignored', () async {
      final vm = create();
      final gate = Completer<FavoriteCheckDto>();
      api.onCheck = (_) => gate.future;
      final loading = vm.load();
      guard
        ..invalidate()
        ..startSession('other@example.com');
      gate.complete(const FavoriteCheckDto(movieId: 550, isFavorite: true));
      await loading;
      expect(vm.isFavorite, isFalse);
      expect(vm.hasLoadedStatus, isFalse);
      // 이전 세션의 늦은 401도 현재 세션을 정리하지 않습니다.
      api.onCheck = (_) async => throw fakeInvalidToken('/v8/favorites/550');
      await vm.load();
      expect(expireCalls, 0);
    });
  });

  group('PagedMoviesViewModel', () {
    late _PagedTmdbService service;
    late PagedMoviesViewModel vm;

    setUp(() {
      service = _PagedTmdbService();
      vm = PagedMoviesViewModel(tmdbApi: service);
    });
    tearDown(() => vm.dispose());

    test(
      'more appends without duplicates; failure retries the same page',
      () async {
        await vm.loadInitial();
        expect(
          (vm.phase, vm.movies.length, vm.nextPage),
          (LoadPhase.ready, 4, 2),
        );

        await vm.loadNextPage();
        expect(vm.movies.length, 8); // 중복 1개는 빠집니다.
        expect(vm.movies.map((m) => m.id).toSet().length, 8);

        service.failOnce.add(3);
        await vm.loadNextPage();
        expect(vm.loadMoreError, isNotNull);
        expect((vm.movies.length, vm.nextPage), (8, 3)); // 기존 목록·page 유지

        await vm.loadNextPage();
        expect(vm.loadMoreError, isNull);
        expect(vm.movies.length, 12);
        expect(vm.hasMore, isFalse);
        expect(service.calls.map((c) => c.$1), [1, 2, 3, 3]);

        // 마지막 page 뒤에는 요청하지 않습니다.
        await vm.loadNextPage();
        expect(service.calls, hasLength(4));
      },
    );

    test('a slow response of the previous genre is ignored', () async {
      final slow = Completer<void>();
      service.gates['genre:null'] = slow;
      final first = vm.loadInitial();
      final second = vm.loadInitial(genreId: 18);
      await second;
      expect(vm.movies.first.title, startsWith('장르18'));

      slow.complete();
      await first;
      expect(vm.movies.every((m) => m.title.startsWith('장르18')), isTrue);
      expect(vm.genreId, 18);
    });

    test('changing the condition during load more drops that page', () async {
      await vm.loadInitial();
      final slow = Completer<void>();
      service.gates['genre:null'] = slow;
      final more = vm.loadNextPage();
      expect(vm.isLoadingMore, isTrue);
      service.gates.remove('genre:null');
      await vm.loadInitial(genreId: 18);
      slow.complete();
      await more;
      expect(vm.isLoadingMore, isFalse);
      expect(vm.movies.every((m) => m.title.startsWith('장르18')), isTrue);
      expect(vm.nextPage, 2);
    });

    test('total pages are capped at 500', () async {
      final big = PagedMoviesViewModel(
        tmdbApi: _PagedTmdbService(totalPages: 46000),
      );
      addTearDown(big.dispose);
      await big.loadInitial();
      expect(big.totalPages, PagedMoviesViewModel.maxTmdbPage);
    });

    test('empty search result is empty, not error', () async {
      service.emptyQueries.add('없는영화');
      await vm.loadInitial(query: '  없는영화 ');
      expect(vm.phase, LoadPhase.empty);
      expect(service.calls.single, (1, null, '없는영화'));
    });

    test('dispose during a request does not notify', () async {
      final slow = Completer<void>();
      service.gates['genre:null'] = slow;
      final local = PagedMoviesViewModel(tmdbApi: service);
      final loading = local.loadInitial();
      local.dispose();
      slow.complete();
      await loading; // dispose 뒤 notify하면 예외가 납니다.
    });
  });

  group('Movie detail bookmark', () {
    TestApp detailApp() => TestApp(
      movieService: _PagedTmdbService(movies: {550: fakeMovie(550, '파이트 클럽')}),
    );

    testWidgets('icon and snackbar follow the server result', (tester) async {
      final app = await pumpApp(
        tester,
        detailApp(),
        initialLocation: '/movies/550',
      );
      expect(bookmarkButton(), findsOneWidget);
      expect(app.favoriteApi.log, ['GET 550']);

      final gate = Completer<void>();
      app.favoriteApi.onAdd = (movieId) async {
        await gate.future;
        return FavoriteResponseDto(
          favoriteId: 9,
          movieId: movieId,
          createdAt: DateTime.utc(2026),
        );
      };
      await tester.tap(bookmarkButton());
      await tester.pump();
      // 요청 중에는 북마크 자리에만 인디케이터가 보입니다.
      expect(find.bySemanticsLabel('즐겨찾기 요청 중'), findsOneWidget);
      expect(bookmarkButton(), findsNothing);
      gate.complete();
      await tester.pumpAndSettle();
      expect(unbookmarkButton(), findsOneWidget);
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      expect(find.text('즐겨찾기에 추가했습니다.'), findsOneWidget);

      app.favoriteApi.onAdd = null;
      app.favoriteApi.onDelete = (_) async =>
          throw fakeDioError('/v8/favorites/550');
      await tester.tap(unbookmarkButton());
      await tester.pumpAndSettle();
      expect(find.text('즐겨찾기 해제에 실패했습니다.'), findsOneWidget);
      expect(unbookmarkButton(), findsOneWidget); // 이전 상태 유지
    });

    testWidgets('mock movies have no server bookmark', (tester) async {
      final app = await pumpApp(
        tester,
        TestApp(),
        initialLocation: '/movies/under-the-starlight',
      );
      // 3주차의 화면 내부 mock 즐겨찾기를 없앴고, mock 영화는 서버에 저장할 수 없습니다.
      expect(find.text('즐겨찾기'), findsNothing);
      expect(find.byIcon(Icons.bookmark_border), findsNothing);
      expect(app.favoriteApi.log, isEmpty);
    });

    testWidgets('a failed status check offers a refresh, not a toggle', (
      tester,
    ) async {
      final app = detailApp();
      app.favoriteApi.onCheck = (_) async =>
          throw fakeDioError('/v8/favorites/550');
      await pumpApp(tester, app, initialLocation: '/movies/550');
      expect(bookmarkButton(), findsNothing);
      expect(find.byTooltip('즐겨찾기 여부 다시 확인'), findsOneWidget);

      app.favoriteApi.onCheck = null;
      await tester.tap(find.byTooltip('즐겨찾기 여부 다시 확인'));
      await tester.pumpAndSettle();
      expect(bookmarkButton(), findsOneWidget);
    });
  });

  group('My favorites', () {
    TestApp favoritesApp({Set<int> failing = const {}}) {
      final app = TestApp(
        movieService: _PagedTmdbService(
          movies: {
            550: fakeMovie(550, '파이트 클럽'),
            13: fakeMovie(13, '포레스트 검프'),
            680: fakeMovie(680, '펄프 픽션'),
          },
          failingIds: {...failing},
        ),
      );
      app.favoriteApi.seed('movie@example.com', [550, 13]);
      return app;
    }

    testWidgets('my page row opens the list without NavigationBar', (
      tester,
    ) async {
      final app = await pumpApp(tester, favoritesApp(), initialLocation: '/my');
      final ratings = tester.getTopLeft(find.text('내가 등록한 평점'));
      final favorites = tester.getTopLeft(find.text('내 즐겨찾기'));
      expect(favorites.dy, greaterThan(ratings.dy)); // 평점 행 아래

      await tester.tap(find.text('내 즐겨찾기'));
      await tester.pumpAndSettle();
      expect(app.location, '/my/favorites');
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(BackButton), findsOneWidget);
      // 최근에 등록한 영화가 위에 옵니다. TMDB 정보로 제목을 채웁니다.
      final titles = tester
          .widgetList<MovieRowCard>(find.byType(MovieRowCard))
          .map((card) => card.movie?.title)
          .toList();
      expect(titles, ['포레스트 검프', '파이트 클럽']);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(app.location, '/my');
    });

    testWidgets('empty and error are different screens', (tester) async {
      final app = TestApp();
      app.favoriteApi.onList = () async => throw fakeDioError('/v8/favorites');
      await pumpApp(tester, app, initialLocation: '/my/favorites');
      expect(find.text('즐겨찾기를 불러오지 못했습니다.'), findsOneWidget);

      app.favoriteApi.onList = null;
      await tester.tap(find.widgetWithText(MovieLogButton, '다시 시도'));
      await tester.pumpAndSettle();
      expect(find.text('아직 즐겨찾기한 영화가 없습니다.'), findsOneWidget);
    });

    testWidgets('one TMDB failure keeps other cards and retries only it', (
      tester,
    ) async {
      final app = favoritesApp(failing: {13});
      await pumpApp(tester, app, initialLocation: '/my/favorites');
      expect(find.text('파이트 클럽'), findsOneWidget);
      expect(find.text('TMDB #13'), findsOneWidget);
      expect(find.text('정보 다시 불러오기'), findsOneWidget);

      final service = app.movieService as _PagedTmdbService;
      service.failingIds = {};
      service.lookups.clear();
      app.favoriteApi.log.clear();
      await tester.tap(find.text('정보 다시 불러오기'));
      await tester.pumpAndSettle();
      expect(find.text('포레스트 검프'), findsOneWidget);
      expect(service.lookups, [13]); // 그 카드만 다시 요청
      expect(app.favoriteApi.log, isEmpty); // 목록 GET은 다시 보내지 않음
    });

    testWidgets('unfavorite in detail, back → the list is refreshed', (
      tester,
    ) async {
      final app = await pumpApp(
        tester,
        favoritesApp(),
        initialLocation: '/my/favorites',
      );
      await tester.tap(find.text('파이트 클럽'));
      await tester.pumpAndSettle();
      expect(app.location, '/movies/550');
      await tester.tap(unbookmarkButton());
      await tester.pumpAndSettle();
      expect(find.text('즐겨찾기에서 삭제했습니다.'), findsOneWidget);

      // 상세의 뒤로 가기 버튼(context.pop)과 같은 동작입니다.
      app.router.pop();
      await tester.pumpAndSettle();
      expect(app.location, '/my/favorites');
      expect(find.text('파이트 클럽'), findsNothing);
      expect(find.text('포레스트 검프'), findsOneWidget);
    });

    testWidgets('logout → other account never shows the previous list', (
      tester,
    ) async {
      final app = favoritesApp();
      app.favoriteApi.seed(_otherMember.email, [680]);
      var current = fakeMember;
      app.memberApi.onFetch = () async => current;
      await pumpApp(tester, app, initialLocation: '/my/favorites');
      expect(find.text('파이트 클럽'), findsOneWidget);

      // 로그아웃
      app.router.go('/my');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '로그아웃'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('로그아웃'),
        ),
      );
      await tester.pumpAndSettle();
      expect(app.location, '/login');

      // 다른 계정으로 로그인 (JWT가 바뀐 것처럼 서버 계정도 바꿉니다)
      current = MemberInfo(
        email: _otherMember.email,
        nickname: _otherMember.nickname,
        createdAt: DateTime.utc(2026),
      );
      app.favoriteApi.account = _otherMember.email;
      app.authApi.onLogin = (_) async =>
          const LoginResult(nickname: '다른계정', accessToken: 'jwt-2');
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), _otherMember.email);
      await tester.enterText(fields.at(1), 'Pass1234!');
      await tester.tap(find.widgetWithText(MovieLogButton, '로그인'));
      await tester.pumpAndSettle();

      app.router.go('/my');
      await tester.pumpAndSettle();
      await tester.tap(find.text('내 즐겨찾기'));
      await tester.pumpAndSettle();
      expect(find.text('펄프 픽션'), findsOneWidget);
      expect(find.text('파이트 클럽'), findsNothing);
      expect(find.text('포레스트 검프'), findsNothing);
    });

    testWidgets('a late list response of the previous account is ignored', (
      tester,
    ) async {
      final app = favoritesApp();
      final gate = Completer<List<FavoriteResponseDto>>();
      app.favoriteApi.onList = () => gate.future;
      // 목록 응답이 오지 않아 인디케이터가 계속 돌므로 pumpAndSettle 대신 프레임을 넘깁니다.
      useTallScreen(tester);
      await tester.pumpWidget(app.build(initialLocation: '/my/favorites'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(app.location, '/my/favorites');

      // 응답 전에 로그아웃합니다.
      app.router.go('/my');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '로그아웃'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('로그아웃'),
        ),
      );
      await tester.pumpAndSettle();
      gate.complete(app.favoriteApi.store['movie@example.com']!);
      await tester.pumpAndSettle();
      expect(app.location, '/login');
      expect(find.text('파이트 클럽'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AUTH401_4 on the list expires the session once', (
      tester,
    ) async {
      final app = favoritesApp();
      app.favoriteApi.onList = () async => throw fakeCommonError(
        '/v8/favorites',
        401,
        'AUTH401_4',
        '만료된 토큰입니다.',
      );
      await pumpApp(tester, app, initialLocation: '/my/favorites');
      expect(app.location, '/login');
      expect(app.storage.token, isNull);
      expect(find.text('로그인이 만료됐어요. 다시 로그인해 주세요.'), findsOneWidget);
    });
  });

  group('Movie list more and search', () {
    testWidgets('more → loading → append; failure retries the same page', (
      tester,
    ) async {
      final service = _PagedTmdbService(totalPages: 2);
      final app = await pumpApp(
        tester,
        TestApp(movieService: service),
        initialLocation: '/movies',
      );
      expect(find.byType(MovieCard), findsNWidgets(4));
      expect(find.byType(NavigationBar), findsOneWidget);

      service.failOnce.add(2);
      await tester.scrollUntilVisible(
        find.text('더 보기'),
        300,
        scrollable: gridScrollable(),
      );
      await tester.ensureVisible(find.widgetWithText(MovieLogButton, '더 보기'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MovieLogButton, '더 보기'));
      await tester.pumpAndSettle();
      expect(find.text('추가 영화 조회에 실패했습니다.'), findsOneWidget);
      expect(find.byType(MovieCard), findsWidgets); // 기존 카드 유지

      await tester.ensureVisible(find.text('다음 페이지 다시 시도'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('다음 페이지 다시 시도'));
      await tester.pumpAndSettle();
      expect(service.calls.map((c) => c.$1), [1, 2, 2]);
      await tester.scrollUntilVisible(
        find.text('모든 영화를 확인했습니다.'),
        300,
        scrollable: gridScrollable(),
      );
      expect(find.text('더 보기'), findsNothing);
      expect(app.location, '/movies');
    });

    testWidgets('search icon → submit → results → detail', (tester) async {
      final service = _PagedTmdbService(
        totalPages: 1,
        movies: {5000: fakeMovie(5000, '별빛 1p-0')},
      );
      final app = await pumpApp(
        tester,
        TestApp(movieService: service),
        initialLocation: '/movies',
      );
      await tester.tap(find.byTooltip('영화 검색'));
      await tester.pumpAndSettle();
      expect(app.location, '/movies/search');
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('보고 싶은 영화를 검색해 보세요.'), findsOneWidget);

      // 빈 검색어는 서버에 보내지 않습니다.
      final callsBefore = service.calls.length;
      await tester.enterText(find.byType(TextField), '   ');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('검색어를 입력해 주세요.'), findsOneWidget);
      expect(service.calls.length, callsBefore);

      await tester.enterText(find.byType(TextField), '별빛');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(service.calls.last, (1, null, '별빛'));
      expect(find.text('별빛 1p-0'), findsOneWidget);
      expect(find.text('모든 영화를 확인했습니다.'), findsOneWidget);

      await tester.tap(find.text('별빛 1p-0'));
      await tester.pumpAndSettle();
      expect(app.location, '/movies/5000');
    });

    testWidgets('a slow result of the previous query is not mixed in', (
      tester,
    ) async {
      final service = _PagedTmdbService(totalPages: 1);
      service.emptyQueries.add('없는영화');
      await pumpApp(
        tester,
        TestApp(movieService: service),
        initialLocation: '/movies/search',
      );
      final slow = Completer<void>();
      service.gates['query:별빛'] = slow;
      await tester.enterText(find.byType(TextField), '별빛');
      await tester.tap(find.widgetWithText(TextButton, '검색'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '달빛');
      await tester.tap(find.widgetWithText(TextButton, '검색'));
      await tester.pumpAndSettle();
      slow.complete();
      await tester.pumpAndSettle();
      expect(find.textContaining('달빛'), findsWidgets);
      expect(find.textContaining('별빛 1p'), findsNothing);

      await tester.enterText(find.byType(TextField), '없는영화');
      await tester.tap(find.widgetWithText(TextButton, '검색'));
      await tester.pumpAndSettle();
      expect(find.text('검색 결과가 없습니다.'), findsOneWidget);
    });
  });
}

/// 요청을 "METHOD path body" 문자열로 기록하고 JSON 응답을 돌려주는 Adapter입니다.
class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.reply);

  final (int, Object) Function(RequestOptions options) reply;
  final requests = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    var body = '';
    if (requestStream != null) {
      final chunks = await requestStream.toList();
      body = ' ${utf8.decode(chunks.expand((c) => c).toList())}';
    }
    requests.add('${options.method} ${options.uri.path}$body');
    final (status, data) = reply(options);
    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode(data)),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
