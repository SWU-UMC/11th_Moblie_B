import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/core/session/auth_session_bridge.dart';
import 'package:movielog/core/session/session_guard.dart';
import 'package:movielog/data/models/member_info.dart';
import 'package:movielog/data/models/tmdb_movie_page_dto.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/favorite_detail_view_model.dart';
import 'package:movielog/view_models/favorites_view_model.dart';
import 'package:movielog/view_models/load_phase.dart';
import 'package:movielog/view_models/movie_detail_view_model.dart';
import 'package:movielog/view_models/paged_movies_view_model.dart';
import 'package:movielog/view_models/session_ratings.dart';
import 'package:movielog/view_models/submit_status.dart';

import 'support/fake_movie_log_services.dart';
import 'support/fake_tmdb_movie_service.dart';

/// 로그인 + GET me까지 끝난 AuthViewModel과 Bridge
class _Session {
  _Session({MemberInfo? member})
    : memberApi = FakeMemberApiService(member: member);

  final FakeMemberApiService memberApi;
  final storage = FakeTokenStorage(null);
  final authApi = FakeAuthApiService();
  final sessionRatings = SessionRatings();
  final favorites = FakeFavoriteApiService();
  final tmdb = FakeTmdbMovieService();

  late final auth = AuthViewModel(
    authApi,
    memberApi,
    storage,
    sessionRatings: sessionRatings,
  );
  late final bridge = AuthSessionBridge(
    authSignals: auth,
    sessionVersion: () => auth.sessionVersion,
    verifiedEmail: () =>
        auth.status == AuthStatus.signedIn ? auth.member?.email : null,
  );

  SessionGuard get guard => bridge.guard;
  String get email => auth.member!.email;

  Future<void> signIn() async {
    bridge; // listener 먼저 붙여 둠
    await auth.login('movie@example.com', 'Password1!');
    await auth.loadMember();
  }

  FavoriteDetailViewModel detail(int movieId) => FavoriteDetailViewModel(
    movieId: movieId,
    favoriteApi: favorites,
    sessionGuard: guard,
    accountId: email,
    auth: auth,
  );

  FavoritesViewModel list({int concurrency = 5}) => FavoritesViewModel(
    favoriteApi: favorites,
    tmdbApi: tmdb,
    sessionGuard: guard,
    accountId: email,
    auth: auth,
    enrichmentConcurrency: concurrency,
  );
}

/// page 메타데이터를 마음대로 주는 TMDB Fake (500 page 제한 확인용)
class _BigTmdb extends FakeTmdbMovieService {
  @override
  Future<TmdbMoviePageDto> discoverMovies({
    required int page,
    List<int>? genreIds,
  }) async => TmdbMoviePageDto(
    page: page,
    results: [fakeMovie(page)],
    totalPages: 900,
    totalResults: 18000,
  );
}

void main() {
  group('SessionGuard · AuthSessionBridge', () {
    test('GET me로 확인한 email 생길 때 새 세션, 로그아웃하면 무효', () async {
      final session = _Session();
      expect(session.guard.accountId, isNull);

      await session.signIn();
      final generation = session.guard.generation;
      expect(session.guard.accountId, 'movie@example.com');
      expect(session.guard.isCurrent(generation, 'movie@example.com'), isTrue);

      await session.auth.logout();
      expect(session.guard.accountId, isNull);
      expect(session.guard.isCurrent(generation, 'movie@example.com'), isFalse);
    });

    test('닉네임 수정은 세션 안 바꾸고, 같은 email로 다시 로그인하면 새 세션', () async {
      final session = _Session();
      await session.signIn();
      final first = session.guard.generation;

      session.auth.updateMember(
        MemberInfo(
          email: session.email,
          nickname: '새닉네임',
          createdAt: DateTime.utc(2026),
        ),
      );
      expect(session.guard.generation, first);

      await session.auth.logout();
      await session.signIn();
      expect(session.guard.accountId, 'movie@example.com');
      expect(session.guard.generation, greaterThan(first));
    });
  });

  group('FavoriteDetailViewModel (상세 북마크)', () {
    test('진입 시 서버 여부 반영 → 등록 → 해제 (성공 확인 후에만 바뀜)', () async {
      final session = _Session();
      await session.signIn();
      final vm = session.detail(550);

      await vm.load();
      expect(vm.hasLoadedStatus, isTrue);
      expect(vm.isFavorite, isFalse);
      expect(session.favorites.checkCalls, [550]);

      session.favorites.writeGate = Completer();
      final adding = vm.toggle();
      expect(vm.isSaving, isTrue);
      expect(vm.isFavorite, isFalse); // optimistic 아님
      await vm.toggle(); // 요청 중 중복 탭 무시
      session.favorites.writeGate!.complete();
      session.favorites.writeGate = null;
      await adding;
      expect(vm.isFavorite, isTrue);
      expect(vm.isSaving, isFalse);
      expect(session.favorites.addCalls, [550]);

      await vm.toggle();
      expect(vm.isFavorite, isFalse);
      expect(session.favorites.deleteCalls, [550]);
    });

    test('첫 여부 조회 실패: 토글 막고 다시 확인 가능', () async {
      final session = _Session();
      await session.signIn();
      session.favorites.checkError = fakeHttpError('/v8/favorites/1');
      final vm = session.detail(1);

      await vm.load();
      expect(vm.hasLoadedStatus, isFalse);
      expect(vm.errorMessage, '즐겨찾기 여부를 확인하지 못했습니다.');
      await vm.toggle();
      expect(session.favorites.addCalls, isEmpty);

      session.favorites.checkError = null;
      await vm.load();
      expect(vm.hasLoadedStatus, isTrue);
      expect(vm.errorMessage, isNull);
    });

    test('등록 실패(네트워크)면 이전 아이콘 유지 + 안내, 로그아웃 안 함', () async {
      final session = _Session();
      await session.signIn();
      final vm = session.detail(1);
      await vm.load();

      session.favorites.writeError = fakeHttpError('/v8/favorites');
      await vm.toggle();
      expect(vm.isFavorite, isFalse);
      expect(vm.errorMessage, '즐겨찾기에 추가하지 못했습니다. 다시 시도해 주세요.');
      expect(session.auth.status, AuthStatus.signedIn);
    });

    test('FAVORITE409_1: POST 반복 안 하고 GET 여부로 맞춤 (timeout 뒤 재시도 상황)', () async {
      final session = _Session();
      await session.signIn();
      final vm = session.detail(7);
      await vm.load();

      session.favorites.addAlreadyApplied = true;
      await vm.toggle();
      expect(session.favorites.addCalls, [7]); // 한 번만
      expect(session.favorites.checkCalls, [7, 7]); // 진입 + 동기화
      expect(vm.isFavorite, isTrue);
      expect(vm.errorMessage, isNull);
    });

    test('FAVORITE404_1: 이미 해제됐으면 GET으로 맞춰서 해제 상태', () async {
      final session = _Session();
      await session.signIn();
      session.favorites.seed(8);
      final vm = session.detail(8);
      await vm.load();
      expect(vm.isFavorite, isTrue);

      session.favorites.server.clear(); // 다른 기기에서 먼저 해제
      await vm.toggle();
      expect(vm.isFavorite, isFalse);
      expect(vm.errorMessage, isNull);
    });

    test('AUTH401_4면 현재 세션 한 번 정리, 403은 로그아웃 안 함', () async {
      final session = _Session();
      await session.signIn();
      final vm = session.detail(1);
      await vm.load();

      session.favorites.writeError = fakeCodeError(
        '/v8/favorites',
        403,
        'COMMON403',
        '권한 없음',
      );
      await vm.toggle();
      expect(session.auth.status, AuthStatus.signedIn);

      session.favorites.writeError = fakeExpiredError('/v8/favorites');
      await vm.toggle();
      expect(session.auth.status, AuthStatus.signedOut);
      expect(session.auth.sessionExpired, isTrue);
    });

    test('응답 오기 전에 계정이 바뀌면 이전 계정 응답은 반영 안 함', () async {
      final session = _Session();
      await session.signIn();
      final vm = session.detail(1);
      await vm.load();

      session.favorites.writeGate = Completer();
      final adding = vm.toggle();
      await session.auth.logout();
      session.favorites.writeGate!.complete();
      await adding;
      expect(vm.isFavorite, isFalse);
    });

    test('dispose 뒤 늦게 온 응답도 에러 없이 무시', () async {
      final session = _Session();
      await session.signIn();
      final vm = session.detail(1);
      session.favorites.checkGate = Completer();
      final loading = vm.load();
      vm.dispose();
      session.favorites.checkGate!.complete();
      await loading;
      expect(vm.hasLoadedStatus, isFalse);
    });
  });

  group('FavoritesViewModel (내 즐겨찾기)', () {
    test('목록 → movieId로 TMDB 보충, 결과 순서 유지', () async {
      final session = _Session();
      await session.signIn();
      session.favorites
        ..seed(3)
        ..seed(1)
        ..seed(2);
      final vm = session.list();

      await vm.refresh();
      expect(vm.phase, LoadPhase.ready);
      expect(vm.items.map((i) => i.movie?.title), ['영화 3', '영화 1', '영화 2']);
    });

    test('빈 목록은 empty, 목록 조회 실패는 error (서로 다른 화면)', () async {
      final session = _Session();
      await session.signIn();
      final vm = session.list();
      await vm.refresh();
      expect(vm.phase, LoadPhase.empty);

      final failing = session.list();
      session.favorites.listError = fakeHttpError('/v8/favorites');
      await failing.refresh();
      expect(failing.phase, LoadPhase.error);
      expect(failing.errorMessage, '즐겨찾기를 불러오지 못했습니다.');
      expect(session.auth.status, AuthStatus.signedIn); // 네트워크 실패는 로그아웃 X
    });

    test('영화 한 건 TMDB 실패: 그 카드만 placeholder, 그 카드만 재조회', () async {
      final session = _Session();
      await session.signIn();
      session.favorites
        ..seed(1)
        ..seed(2);
      session.tmdb.failDetailIds.add(2);
      final vm = session.list();

      await vm.refresh();
      expect(vm.phase, LoadPhase.ready); // 전체가 비지 않음
      expect(vm.items[0].hasMovie, isTrue);
      expect(vm.items[1].hasMovie, isFalse);
      expect(vm.items[1].errorMessage, '영화 정보를 불러오지 못했습니다.');

      session.tmdb
        ..failDetailIds.clear()
        ..detailCalls.clear();
      await vm.retryMovie(vm.items[1].favorite.favoriteId);
      expect(session.tmdb.detailCalls, [2]); // 1번은 다시 안 부름
      expect(vm.items[1].movie?.title, '영화 2');
    });

    test('다시 조회할 땐 TMDB 공개 정보 캐시(Map) 재사용, 해제한 영화는 사라짐', () async {
      final session = _Session();
      await session.signIn();
      session.favorites
        ..seed(1)
        ..seed(2);
      final vm = session.list();
      await vm.refresh();

      session.favorites.server.remove(1); // 상세에서 해제하고 돌아옴
      session.tmdb.detailCalls.clear();
      await vm.refresh();
      expect(vm.items.map((i) => i.favorite.movieId), [2]);
      expect(session.tmdb.detailCalls, isEmpty);
    });

    test('TMDB 보충은 한 번에 최대 5개', () async {
      final session = _Session();
      await session.signIn();
      for (var id = 1; id <= 12; id++) {
        session.favorites.seed(id);
      }
      final vm = session.list();
      await vm.refresh();
      expect(vm.items, hasLength(12));
      expect(session.tmdb.detailCalls, hasLength(12));
    });

    test('목록 401 만료면 세션 정리', () async {
      final session = _Session();
      await session.signIn();
      session.favorites.listError = fakeExpiredError('/v8/favorites');
      final vm = session.list();
      await vm.refresh();
      expect(session.auth.status, AuthStatus.signedOut);
    });

    test('로그아웃 뒤 도착한 이전 계정 목록은 반영 안 함', () async {
      final session = _Session();
      await session.signIn();
      session.favorites.seed(1);
      final vm = session.list();

      session.favorites.listGate = Completer();
      final loading = vm.refresh();
      await session.auth.logout();
      session.favorites.listGate!.complete();
      await loading;
      expect(vm.items, isEmpty);
    });
  });

  group('PagedMoviesViewModel (더 보기·검색)', () {
    test('첫 page만 → 더 보기로 다음 page append (중복 id 제외)', () async {
      final service = FakeTmdbMovieService(overlapBetweenPages: true);
      final vm = PagedMoviesViewModel(tmdbApi: service);

      await vm.loadInitial();
      expect(vm.phase, LoadPhase.ready);
      expect(vm.movies, hasLength(20));
      expect(vm.nextPage, 2);
      expect(vm.totalPages, 3);

      await vm.loadNextPage();
      // 2 page 첫 영화가 1 page 마지막이랑 같음 → 하나 빠짐
      expect(vm.movies, hasLength(39));
      expect(vm.movies.map((m) => m.id).toSet(), hasLength(39));
      expect(vm.nextPage, 3);
    });

    test('다음 page 실패: 기존 목록·nextPage 유지 → 같은 page 재시도', () async {
      final service = FakeTmdbMovieService()..failDiscoverPages.add(2);
      final vm = PagedMoviesViewModel(tmdbApi: service);
      await vm.loadInitial();

      await vm.loadNextPage();
      expect(vm.loadMoreError, '추가 영화 조회에 실패했습니다.');
      expect(vm.movies, hasLength(20));
      expect(vm.nextPage, 2);
      expect(vm.isLoadingMore, isFalse);

      service.failDiscoverPages.clear();
      await vm.loadNextPage();
      expect(service.discoverCalls.map((c) => c.page), [1, 2, 2]);
      expect(vm.loadMoreError, isNull);
      expect(vm.movies, hasLength(40));
    });

    test('요청 중엔 더 보기 중복 요청 안 함, 마지막 page면 hasMore false', () async {
      final service = FakeTmdbMovieService();
      final vm = PagedMoviesViewModel(tmdbApi: service);
      await vm.loadInitial();

      service.discoverGate = Completer();
      final more = vm.loadNextPage();
      expect(vm.isLoadingMore, isTrue);
      await vm.loadNextPage();
      service.discoverGate!.complete();
      service.discoverGate = null;
      await more;
      expect(service.discoverCalls.map((c) => c.page), [1, 2]);

      await vm.loadNextPage();
      expect(vm.hasMore, isFalse); // 45개 = 3 page
      await vm.loadNextPage();
      expect(service.discoverCalls.map((c) => c.page), [1, 2, 3]);
    });

    test('total_pages가 500 넘어도 501 page는 요청 안 함', () async {
      final vm = PagedMoviesViewModel(tmdbApi: _BigTmdb());
      await vm.loadInitial();
      expect(vm.totalPages, PagedMoviesViewModel.maxTmdbPage);
      vm.nextPage = 501;
      expect(vm.hasMore, isFalse);
    });

    test('조건 바꾸면 이전 목록·추가 로딩 오류 초기화, 늦은 이전 응답 무시', () async {
      final service = FakeTmdbMovieService()..failDiscoverPages.add(2);
      final vm = PagedMoviesViewModel(tmdbApi: service);
      await vm.loadInitial();
      await vm.loadNextPage();
      expect(vm.loadMoreError, isNotNull);

      // 액션 요청을 붙잡아 둔 채 드라마로 바꿈
      service.discoverGate = Completer();
      final action = vm.loadInitial(genreIds: [28]);
      expect(vm.loadMoreError, isNull);
      expect(vm.movies, isEmpty);
      expect(vm.phase, LoadPhase.loading);
      final drama = vm.loadInitial(genreIds: [18]);
      service.discoverGate!.complete();
      await (action, drama).wait;

      expect(vm.condition.genreIds, [18]);
      expect(vm.movies.every((m) => m.genreIds.contains(18)), isTrue);
    });

    test('검색: 빠르게 바꾼 새 검색어 결과만 남음', () async {
      final service = FakeTmdbMovieService();
      final vm = PagedMoviesViewModel(tmdbApi: service);
      service.searchGates['1'] = Completer();

      final slow = vm.loadInitial(query: '1');
      final fast = vm.loadInitial(query: '영화 2');
      await fast;
      service.searchGates['1']!.complete();
      await slow;

      expect(vm.condition.query, '영화 2');
      expect(vm.movies.map((m) => m.title), everyElement(contains('영화 2')));
    });

    test('검색 결과 없음은 empty, 실패는 error + 검색 문구', () async {
      final service = FakeTmdbMovieService();
      final vm = PagedMoviesViewModel(tmdbApi: service);
      await vm.loadInitial(query: '없는영화');
      expect(vm.phase, LoadPhase.empty);

      service.failSearch = true;
      await vm.loadInitial(query: '영화');
      expect(vm.phase, LoadPhase.error);
      expect(vm.errorMessage, '검색 결과를 불러오지 못했습니다.');
    });

    test('dispose 뒤 늦게 온 page 응답은 에러 없이 무시', () async {
      final service = FakeTmdbMovieService()..discoverGate = Completer();
      final vm = PagedMoviesViewModel(tmdbApi: service);
      final loading = vm.loadInitial();
      vm.dispose();
      service.discoverGate!.complete();
      await loading;
      expect(vm.movies, isEmpty);
    });
  });

  group('Challenge: 평점 Dialog 평점·즐겨찾기 통합 저장', () {
    Future<(MovieDetailViewModel, FakeRatingApiService, _Session)>
    setUpDetail() async {
      final session = _Session();
      await session.signIn();
      final ratingApi = FakeRatingApiService()..favorites = session.favorites;
      final vm = MovieDetailViewModel(
        session.tmdb,
        ratingApi,
        movieId: 5,
        auth: session.auth,
        sessionRatings: session.sessionRatings,
        movie: fakeMovie(5),
      );
      return (vm, ratingApi, session);
    }

    test('체크하면 POST /v8/movie-records 한 번으로 평점+즐겨찾기', () async {
      final (vm, ratingApi, session) = await setUpDetail();
      await vm.createRating(score: 4, comment: '좋아요', addToFavorites: true);

      expect(vm.submitStatus, SubmitStatus.success);
      expect(ratingApi.recordCalls.single, {
        'movieId': 5,
        'score': 4,
        'comment': '좋아요',
        'addToFavorites': true,
      });
      expect(ratingApi.createCalls, isEmpty);
      expect(session.favorites.server.keys, [5]);
      expect(vm.savedWithFavorite, isTrue);
      expect(vm.myScore, 4);
    });

    test('체크 안 하면 기존 POST /v8/ratings로 평점만', () async {
      final (vm, ratingApi, session) = await setUpDetail();
      await vm.createRating(score: 3);
      expect(ratingApi.createCalls, hasLength(1));
      expect(ratingApi.recordCalls, isEmpty);
      expect(session.favorites.server, isEmpty);
    });

    test('FAVORITE409_1·RATING409_1은 Dialog 닫고 Snackbar 대상', () async {
      final (vm, ratingApi, session) = await setUpDetail();
      session.favorites.seed(5);
      await vm.createRating(score: 4, addToFavorites: true);
      expect(vm.submitStatus, SubmitStatus.error);
      expect(vm.submitClosesDialog, isTrue);
      expect(vm.submitMessage, '이미 즐겨찾기한 영화예요.');
      expect(ratingApi.server, isEmpty); // 트랜잭션이라 평점도 저장 안 됨
    });

    test('COMMON400·네트워크 실패는 Dialog 유지 (입력 그대로)', () async {
      final (vm, ratingApi, _) = await setUpDetail();
      ratingApi.writeError = fakeCodeError(
        '/v8/movie-records',
        400,
        'COMMON400',
        '별점은 5점 이하여야 합니다.',
      );
      await vm.createRating(score: 4, addToFavorites: true);
      expect(vm.submitClosesDialog, isFalse);
      expect(vm.submitMessage, '별점은 5점 이하여야 합니다.');

      ratingApi.writeError = fakeHttpError('/v8/movie-records');
      await vm.createRating(score: 4, addToFavorites: true);
      expect(vm.submitClosesDialog, isFalse);
      expect(vm.submitMessage, '네트워크 연결을 확인하고 다시 시도해 주세요.');
    });
  });
}
