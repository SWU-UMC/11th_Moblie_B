// 9주차 스터디 인증 캡처용 시나리오입니다. 실제 TMDB·MovieLog API로 앱을 조작하며
// 화면을 PNG로 저장합니다. (영상은 저장한 프레임을 GIF로 묶습니다)
//
// 웹(Chrome)에서 flutter drive로 실행합니다. 웹 앱은 파일을 쓸 수 없으므로
// 캡처한 PNG를 이 PC의 수신 서버(127.0.0.1:8765)로 보내 저장합니다.
//
// flutter drive --driver=test_driver/integration_test.dart \
//   --target=integration_test/week9_capture_test.dart -d chrome \
//   --dart-define=CAP_PW=...
//
// - 토큰은 메모리 저장소에만 두어 브라우저 저장소를 건드리지 않습니다.
// - 실패·지연 화면은 실제 Service를 감싼 Wrapper가 해당 요청 한 번만 바꿉니다.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'package:movielog/core/network/movie_log_client.dart';
import 'package:movielog/core/network/tmdb_client.dart';
import 'package:movielog/core/storage/token_storage.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/favorite_response_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page.dart';
import 'package:movielog/data/services/favorite_api_service.dart';
import 'package:movielog/data/services/sign_up_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/main.dart';
import 'package:movielog/widgets/movie_card.dart';
import 'package:movielog/widgets/movie_row_card.dart';
import 'package:movielog/widgets/movielog_button.dart';

const _pw = String.fromEnvironment('CAP_PW');

/// 캡처 수신 서버입니다. (localhost 전용, MovieLog·TMDB Client와 별개)
final _receiver = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8765'));

Future<void> _send(String path, Map<String, String> query, Uint8List bytes) =>
    _receiver.post<void>(
      path,
      queryParameters: query,
      data: bytes,
      options: Options(contentType: 'application/octet-stream'),
    );

const _accountA = (email: 'lemon.w9cap.a@example.com', nickname: '레몬캡처A');
const _accountB = (email: 'lemon.w9cap.b@example.com', nickname: '레몬캡처B');

/// 기생충(2019) — B 계정에만 즐겨찾기해 계정 전환을 구분합니다.
const _parasiteId = 496243;

class _MemoryTokenStorage implements TokenStorage {
  String? _token;
  @override
  Future<void> deleteAccessToken() async => _token = null;
  @override
  Future<String?> readAccessToken() async => _token;
  @override
  Future<void> saveAccessToken(String token) async => _token = token;
}

DioException _injected(String path) => DioException(
  requestOptions: RequestOptions(path: path),
  message: '캡처용으로 한 번 실패시킨 요청',
);

/// 실제 TMDB Service에 "한 번 실패"·"지연"만 덧붙입니다.
class _CaptureTmdb extends TmdbMovieService {
  _CaptureTmdb() : super(createTmdbClient());

  bool failNextPageOnce = false;
  bool failSearchOnce = false;
  final failDetailOnce = <int>{};
  Duration pageDelay = Duration.zero;

  @override
  Future<TmdbMoviePageDto> discoverMovies({
    required int page,
    int? genreId,
  }) async {
    await Future<void>.delayed(pageDelay);
    if (page > 1 && failNextPageOnce) {
      failNextPageOnce = false;
      throw _injected('/discover/movie');
    }
    return super.discoverMovies(page: page, genreId: genreId);
  }

  @override
  Future<TmdbMoviePageDto> searchMovies({
    required int page,
    required String query,
  }) async {
    await Future<void>.delayed(pageDelay);
    if (failSearchOnce) {
      failSearchOnce = false;
      throw _injected('/search/movie');
    }
    return super.searchMovies(page: page, query: query);
  }

  @override
  Future<TmdbMovieDto> fetchMovieDetail(int movieId) async {
    if (failDetailOnce.remove(movieId)) throw _injected('/movie/$movieId');
    return super.fetchMovieDetail(movieId);
  }
}

/// 실제 즐겨찾기 Service에 "지연"·"목록 한 번 실패"만 덧붙입니다.
class _CaptureFavorites extends FavoriteApiService {
  _CaptureFavorites(super.dio);

  Duration writeDelay = Duration.zero;
  bool failListOnce = false;

  @override
  Future<FavoriteResponseDto> addFavorite({required int movieId}) async {
    await Future<void>.delayed(writeDelay);
    return super.addFavorite(movieId: movieId);
  }

  @override
  Future<void> deleteFavorite({required int movieId}) async {
    await Future<void>.delayed(writeDelay);
    return super.deleteFavorite(movieId: movieId);
  }

  @override
  Future<List<FavoriteResponseDto>> fetchMyFavorites() async {
    if (failListOnce) {
      failListOnce = false;
      await Future<void>.delayed(const Duration(milliseconds: 400));
      throw _injected('/v8/favorites');
    }
    return super.fetchMyFavorites();
  }
}

/// 앱 전체를 감싼 RepaintBoundary를 PNG로 저장하고, 영상용 프레임을 모읍니다.
class _Recorder {
  _Recorder(this.key);

  final GlobalKey key;
  Timer? _timer;
  String? _clip;
  int _frame = 0;
  bool _busy = false;
  final _taps = <Map<String, Object>>[];

  RenderRepaintBoundary get _boundary =>
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pump(const Duration(milliseconds: 50));
    while (_busy) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final image = await _boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await _send('/shot', {'name': name}, data!.buffer.asUint8List());
    debugPrint('[캡처] $name.png');
  }

  void startClip(String name) {
    _clip = name;
    _frame = 0;
    _taps.clear();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _grab());
  }

  Future<void> _grab() async {
    final clip = _clip;
    if (clip == null || _busy) return;
    final boundary = _boundary;
    if (boundary.debugNeedsPaint) return;
    _busy = true;
    try {
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final index = _frame++;
      await _send('/frame', {
        'clip': clip,
        'file': '${index.toString().padLeft(4, '0')}.png',
      }, data!.buffer.asUint8List());
    } finally {
      _busy = false;
    }
  }

  void markTap(Offset at) =>
      _taps.add({'frame': _frame, 'x': at.dx, 'y': at.dy});

  Future<void> stopClip() async {
    _timer?.cancel();
    while (_busy) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final clip = _clip!;
    await _send('/frame', {
      'clip': clip,
      'file': 'taps.json',
    }, utf8.encode(jsonEncode(_taps)));
    debugPrint('[캡처] $clip 프레임 $_frame장');
    _clip = null;
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('week 9 capture', (tester) async {
    expect(_pw, isNotEmpty, reason: 'CAP_PW가 필요합니다.');
    binding.testTextInput.register();
    await dotenv.load(fileName: '.env');

    // 실제 API 로그를 파일로도 남깁니다. (Interceptor가 이미 토큰·비밀번호를 가립니다)
    final logs = <String>[];
    final originalPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      logs.add(message ?? '');
      originalPrint(message, wrapWidth: wrapWidth);
    };
    addTearDown(() => debugPrint = originalPrint);

    // 폰 화면 크기(390×780)로 그립니다.
    tester.view.physicalSize = const Size(780, 1560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final storage = _MemoryTokenStorage();
    final tmdb = _CaptureTmdb();
    final favorites = _CaptureFavorites(createAuthMovieLogClient(storage));
    late GoRouter router;
    final boundaryKey = GlobalKey();
    final rec = _Recorder(boundaryKey);

    // 캡처 전용 계정을 준비합니다. 이미 있으면(409) 그대로 씁니다.
    final signUp = SignUpService(createMovieLogClient());
    for (final account in [_accountA, _accountB]) {
      try {
        await signUp.signUp(
          CreateMemberRequest(
            email: account.email,
            password: _pw,
            nickname: account.nickname,
          ),
        );
      } on DioException catch (error) {
        if (error.response?.statusCode != 409) rethrow;
      }
    }

    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MovieLogApp(
          initialLocation: '/login',
          tokenStorage: storage,
          movieService: tmdb,
          favoriteApiService: favorites,
          onRouterCreated: (value) => router = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> settle([int ms = 600]) async {
      await tester.pumpAndSettle();
      await tester.pump(Duration(milliseconds: ms));
    }

    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      rec.markTap(tester.getCenter(finder));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(finder);
    }

    Future<void> type(Finder field, String text) async {
      await tester.tap(field);
      await tester.pump();
      await tester.enterText(field, text);
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> login(({String email, String nickname}) account) async {
      final fields = find.byType(TextFormField);
      await type(fields.at(0), account.email);
      await type(fields.at(1), _pw);
      await tap(find.widgetWithText(MovieLogButton, '로그인'));
      await settle(1200);
      expect(router.state.uri.path, '/home');
    }

    Future<void> logout() async {
      router.go('/my');
      await settle();
      await tap(find.widgetWithText(TextButton, '로그아웃'));
      await settle();
      await tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('로그아웃'),
        ),
      );
      await settle(1000);
      expect(router.state.uri.path, '/login');
    }

    Future<void> clearMyFavorites() async {
      for (final favorite in await favorites.fetchMyFavorites()) {
        await favorites.deleteFavorite(movieId: favorite.movieId);
      }
    }

    Finder gridScrollable() => find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    );

    Future<void> back() async {
      router.pop();
      await settle(900);
    }

    // ── 계정 A 로그인, 이전 실행의 즐겨찾기 정리 ──
    await login(_accountA);
    await clearMyFavorites();

    // ── 영상 1: 영화 목록 더 보기 → 다음 page 실패 → 같은 page 재시도 ──
    tmdb.pageDelay = const Duration(milliseconds: 900);
    rec.startClip('movies_more');
    await tap(find.text('영화'));
    await settle(1500);
    await tester.scrollUntilVisible(
      find.widgetWithText(MovieLogButton, '더 보기'),
      400,
      scrollable: gridScrollable(),
      duration: const Duration(milliseconds: 120),
    );
    await settle(700);
    await tap(find.widgetWithText(MovieLogButton, '더 보기'));
    await tester.pump(const Duration(milliseconds: 400));
    await rec.shot(tester, 'movies_more_loading');
    await settle(800);
    await tester.drag(gridScrollable(), const Offset(0, -500));
    await settle(500);
    tmdb.failNextPageOnce = true;
    await tester.scrollUntilVisible(
      find.widgetWithText(MovieLogButton, '더 보기'),
      400,
      scrollable: gridScrollable(),
      duration: const Duration(milliseconds: 120),
    );
    await settle(600);
    await tap(find.widgetWithText(MovieLogButton, '더 보기'));
    await settle(1200);
    await rec.shot(tester, 'movies_next_page_error');
    await tap(find.widgetWithText(MovieLogButton, '다음 페이지 다시 시도'));
    await tester.pump(const Duration(milliseconds: 400));
    await settle(1200);
    await tester.drag(gridScrollable(), const Offset(0, -500));
    await settle(1200);
    await rec.stopClip();
    await rec.shot(tester, 'movies_next_page_retried');
    tmdb.pageDelay = Duration.zero;

    // ── 영상 2: 영화 상세 북마크 등록·해제 (아이콘 변경 + Snackbar) ──
    await tester.drag(gridScrollable(), const Offset(0, 6000));
    await settle();
    final cards = tester.widgetList<MovieCard>(find.byType(MovieCard)).toList();
    final picks = cards.take(3).map((card) => card.movie).toList();
    favorites.writeDelay = const Duration(milliseconds: 900);
    rec.startClip('detail_favorite');
    await settle(500);
    await tap(find.byKey(ValueKey(picks[0].id)));
    await settle(1500);
    await rec.shot(tester, 'detail_before');
    await tap(find.byTooltip('즐겨찾기 등록'));
    await tester.pump(const Duration(milliseconds: 350));
    await rec.shot(tester, 'detail_saving');
    await settle(1500);
    await rec.shot(tester, 'detail_after');
    await tester.pump(const Duration(milliseconds: 1500));
    await tap(find.byTooltip('즐겨찾기 해제'));
    await settle(2200);
    await tap(find.byTooltip('즐겨찾기 등록'));
    await settle(2000);
    await rec.stopClip();
    favorites.writeDelay = Duration.zero;
    await back();

    // 내 즐겨찾기에 보일 영화 2편을 더 등록합니다. (상세 화면에서 북마크)
    for (final movie in picks.skip(1)) {
      await tap(find.byKey(ValueKey(movie.id)));
      await settle(1200);
      await tap(find.byTooltip('즐겨찾기 등록'));
      await settle(1500);
      await back();
    }

    // ── 영상 3: 마이페이지 → 내 즐겨찾기 → 상세 해제 → 뒤로가기 갱신 ──
    favorites.writeDelay = const Duration(milliseconds: 600);
    rec.startClip('favorites_refresh');
    await tap(find.text('마이'));
    await settle(1200);
    await rec.shot(tester, 'my_page');
    await tap(find.text('내 즐겨찾기'));
    await settle(2000);
    await rec.shot(tester, 'favorites_list');
    final first = tester.widgetList<MovieRowCard>(find.byType(MovieRowCard));
    final removed = first.first.movie!;
    await tap(find.text(removed.title).first);
    await settle(1500);
    await tap(find.byTooltip('즐겨찾기 해제'));
    await settle(1800);
    await back();
    await settle(1500);
    await rec.stopClip();
    await rec.shot(tester, 'favorites_after_back');
    expect(find.text(removed.title), findsNothing);
    favorites.writeDelay = Duration.zero;

    // ── 내 즐겨찾기: 조회 오류 → 다시 시도 / 영화 정보 한 건 실패 → 그 카드만 재조회 ──
    await back();
    favorites.failListOnce = true;
    await tap(find.text('내 즐겨찾기'));
    await settle(1200);
    await rec.shot(tester, 'favorites_error');
    await tap(find.widgetWithText(MovieLogButton, '다시 시도'));
    await settle(1500);
    await back();
    final remaining = await favorites.fetchMyFavorites();
    tmdb.failDetailOnce.add(remaining.last.movieId);
    await tap(find.text('내 즐겨찾기'));
    await settle(1800);
    await rec.shot(tester, 'favorites_partial_failure');
    await tap(find.text('정보 다시 불러오기'));
    await settle(1500);
    await rec.shot(tester, 'favorites_partial_retried');
    await back();

    // ── 영상 4: 검색 아이콘 → 검색 → 결과 → 상세 ──
    tmdb.pageDelay = const Duration(milliseconds: 500);
    rec.startClip('search');
    await tap(find.text('영화'));
    await settle(800);
    await tap(find.byTooltip('영화 검색'));
    await settle(1000);
    await rec.shot(tester, 'search_idle');
    await type(find.byType(TextField), '해리 포터');
    await tap(find.widgetWithText(TextButton, '검색'));
    await settle(1500);
    await rec.shot(tester, 'search_results');
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -350));
    await settle(800);
    final result = tester
        .widgetList<MovieRowCard>(find.byType(MovieRowCard))
        .first;
    await tap(find.byWidget(result));
    await settle(1800);
    await rec.stopClip();
    await rec.shot(tester, 'search_detail');
    await back();

    // 검색 끝 page·결과 없음·오류 화면
    await type(find.byType(TextField), '기생충');
    await tap(find.widgetWithText(TextButton, '검색'));
    await settle(1500);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -2000));
    await settle(800);
    await rec.shot(tester, 'search_last_page');
    await type(find.byType(TextField), 'qzxwv무비로그없는영화');
    await tap(find.widgetWithText(TextButton, '검색'));
    await settle(1500);
    await rec.shot(tester, 'search_empty');
    tmdb.failSearchOnce = true;
    await type(find.byType(TextField), '해리 포터');
    await tap(find.widgetWithText(TextButton, '검색'));
    await settle(1500);
    await rec.shot(tester, 'search_error');
    tmdb.pageDelay = Duration.zero;
    await back();

    // ── 계정 전환: A 로그아웃 → B 로그인 → 내 즐겨찾기에 A 목록이 없음 ──
    await logout();
    await login(_accountB);
    await clearMyFavorites();
    await tap(find.text('마이'));
    await settle(1200);
    await tap(find.text('내 즐겨찾기'));
    await settle(1500);
    await rec.shot(tester, 'account_b_empty');
    await back();
    await favorites.addFavorite(movieId: _parasiteId);
    await tap(find.text('내 즐겨찾기'));
    await settle(1800);
    await rec.shot(tester, 'account_b_favorites');
    await back();

    // 다시 A로 돌아와 A 목록만 보이는지 확인합니다.
    await logout();
    await login(_accountA);
    await tap(find.text('마이'));
    await settle(1200);
    await tap(find.text('내 즐겨찾기'));
    await settle(1800);
    await rec.shot(tester, 'account_a_again');
    expect(find.textContaining('기생충'), findsNothing);

    await _send('/log', const {}, utf8.encode(logs.join('\n')));
  });
}
