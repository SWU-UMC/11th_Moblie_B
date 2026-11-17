import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:movielog/core/network/auth_interceptor.dart';
import 'package:movielog/core/network/movie_log_logging_interceptor.dart';
import 'package:movielog/data/models/login_models.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/services/auth_api_service.dart';
import 'package:movielog/data/services/member_api_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/screens/login_screen.dart';
import 'package:movielog/screens/splash_screen.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/session_ratings_view_model.dart';
import 'package:movielog/widgets/movielog_button.dart';

import 'fakes/movie_log_fakes.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  void useTallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Finder dialogButton(String label) => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.widgetWithText(MovieLogButton, label),
  );
  Finder emptyStars() => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byIcon(Icons.star_outline_rounded),
  );
  Finder filledStars() => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byIcon(Icons.star_rounded),
  );
  Finder commentField() => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextField),
  );
  Finder loginButton() => find.widgetWithText(MovieLogButton, '로그인');
  const expiredText = '로그인이 만료됐어요. 다시 로그인해 주세요.';

  Future<TestApp> pumpApp(
    WidgetTester tester, {
    TestApp? app,
    String initialLocation = '/start',
  }) async {
    useTallScreen(tester);
    final testApp = app ?? TestApp();
    await tester.pumpWidget(testApp.build(initialLocation: initialLocation));
    await tester.pumpAndSettle();
    return testApp;
  }

  group('Network layer', () {
    late _RecordingAdapter adapter;

    Dio authDio(InMemoryTokenStorage storage) =>
        Dio(BaseOptions(baseUrl: 'https://workbook.devnoco.com'))
          ..httpClientAdapter = adapter
          ..interceptors.add(AuthInterceptor(storage));

    test('Bearer token goes only to protected MovieLog paths', () async {
      adapter = _RecordingAdapter((_) => (200, '[]'));
      final dio = authDio(InMemoryTokenStorage('secret-token'));

      await dio.get('/v7/members/me');
      await dio.post('/v7/ratings');
      await dio.delete('/v7/ratings/9');
      await dio.get('/v7/members/1/ratings'); // 공개 조회
      await dio.post('/v7/auth/login'); // 로그인

      expect(adapter.authHeaders, [
        'Bearer secret-token',
        'Bearer secret-token',
        'Bearer secret-token',
        null,
        null,
      ]);
      // TMDB 같은 다른 host에는 같은 경로라도 MovieLog JWT를 붙이지 않습니다.
      expect(
        AuthInterceptor.isProtected(
          RequestOptions(
            baseUrl: 'https://api.themoviedb.org/3',
            path: '/v7/ratings',
          ),
        ),
        isFalse,
      );
    });

    test('a stale Authorization header is replaced, never reused', () async {
      adapter = _RecordingAdapter((_) => (200, '{}'));
      final dio = authDio(InMemoryTokenStorage(null));
      await dio.get(
        '/v7/members/me',
        options: Options(headers: {'Authorization': 'Bearer TMDB-token'}),
      );
      expect(adapter.authHeaders, [null]);
    });

    test(
      'storage failure rejects instead of sending without a token',
      () async {
        adapter = _RecordingAdapter((_) => (200, '{}'));
        final storage = InMemoryTokenStorage('t')..fail = true;
        await expectLater(
          authDio(storage).get('/v7/members/me'),
          throwsA(
            isA<DioException>().having((e) => e.error, 'error', isStateError),
          ),
        );
        expect(adapter.authHeaders, isEmpty);
      },
    );

    test('logs hide the token, Authorization value and password', () async {
      final logs = <String>[];
      final original = debugPrint;
      debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
      addTearDown(() => debugPrint = original);

      adapter = _RecordingAdapter(
        (_) => (
          200,
          '{"isSuccess":true,"code":"COMMON200","message":"ok",'
              '"result":{"nickname":"무비러버","accessToken":"jwt-from-server"}}',
        ),
      );
      final dio = authDio(InMemoryTokenStorage('stored-jwt'))
        ..interceptors.add(MovieLogLoggingInterceptor());
      await dio.post(
        '/v7/auth/login',
        data: const LoginRequest(
          email: 'movie@example.com',
          password: 'Secret123!',
        ).toJson(),
      );
      await dio.get('/v7/members/me');

      final all = logs.join('\n');
      expect(all, isNot(contains('jwt-from-server')));
      expect(all, isNot(contains('stored-jwt')));
      expect(all, isNot(contains('Secret123!')));
      expect(all, contains('Authorization: Bearer ***'));
      expect(all, contains('password: ***'));
      expect(all, contains('accessToken: ***'));
    });

    test('v7 services use token paths without memberId', () async {
      adapter = _RecordingAdapter((request) {
        final rating =
            '{"ratingId":12,"movieId":550,"score":4,"comment":"좋아요",'
            '"createdAt":"2026-11-01T00:00:00.000Z",'
            '"updatedAt":"2026-11-02T00:00:00.000Z"}';
        final member =
            '{"email":"movie@example.com","nickname":"새닉네임",'
            '"createdAt":"2026-11-01T00:00:00.000Z"}';
        String ok(String result) =>
            '{"isSuccess":true,"code":"COMMON200","message":"ok",'
            '"result":$result}';
        return switch (request.method) {
          'POST' when request.path == '/v7/auth/login' => (
            200,
            ok('{"nickname":"무비러버","accessToken":"jwt"}'),
          ),
          'POST' => (201, ok(rating)),
          'PATCH' when request.path == '/v7/members/me' => (200, ok(member)),
          'PATCH' => (200, ok(rating)),
          'DELETE' => (200, ok('null')),
          _ => (200, ok(member)),
        };
      });
      final storage = InMemoryTokenStorage('jwt');
      final dio = authDio(storage);
      final ratings = RatingApiService(dio, dio);

      final login = await AuthApiService(dio)
          .login(const LoginRequest(email: 'movie@example.com', password: 'p'));
      final created = await ratings.createRating(
        const CreateRatingRequest(movieId: 550, score: 4, comment: '좋아요'),
      );
      final updated = await ratings.updateRating(
        ratingId: 12,
        score: 4,
        comment: null,
      );
      await ratings.deleteRating(12);
      final me = await MemberApiService(dio).fetchMe();
      final renamed = await MemberApiService(dio).updateNickname('새닉네임');

      expect(login.accessToken, 'jwt');
      expect(login.toString(), isNot(contains('jwt')));
      expect(created.ratingId, 12);
      expect(updated.updatedAt, DateTime.utc(2026, 11, 2));
      expect(me.nickname, '새닉네임');
      expect(renamed.email, 'movie@example.com');
      expect(adapter.requests, [
        ('POST', '/v7/auth/login'),
        ('POST', '/v7/ratings'),
        ('PATCH', '/v7/ratings/12'),
        ('DELETE', '/v7/ratings/12'),
        ('GET', '/v7/members/me'),
        ('PATCH', '/v7/members/me'),
      ]);
      // 등록 body에 memberId가 없고, PATCH는 전체 교체라 comment를 명시적으로 보냅니다.
      expect(jsonDecode(adapter.bodies[1]), {
        'movieId': 550,
        'score': 4,
        'comment': '좋아요',
      });
      expect(jsonDecode(adapter.bodies[2]), {'score': 4, 'comment': null});
    });

    test('delete must be 200, not the old 204', () async {
      adapter = _RecordingAdapter((_) => (204, ''));
      final dio = authDio(InMemoryTokenStorage('jwt'));
      await expectLater(
        RatingApiService(dio, dio).deleteRating(1),
        throwsStateError,
      );
    });
  });

  group('AuthViewModel', () {
    late InMemoryTokenStorage storage;
    late FakeAuthApiService authApi;
    late FakeMemberApiService memberApi;

    AuthViewModel create() => AuthViewModel(authApi, memberApi, storage);

    setUp(() {
      storage = InMemoryTokenStorage();
      authApi = FakeAuthApiService();
      memberApi = FakeMemberApiService();
    });

    test('no saved token → signedOut without GET me', () async {
      final auth = create();
      await auth.restoreSession();
      expect(auth.status, AuthStatus.signedOut);
      expect(memberApi.fetchCount, 0);
    });

    test('saved token is trusted only after GET me succeeds', () async {
      storage.token = 'saved';
      final gate = Completer<void>();
      memberApi.onFetch = () async {
        await gate.future;
        return fakeMember;
      };
      final auth = create();
      final restoring = auth.restoreSession();
      await Future<void>.delayed(Duration.zero);
      // 토큰이 있어도 검증 전에는 initializing입니다.
      expect(auth.status, AuthStatus.initializing);

      gate.complete();
      await restoring;
      expect(auth.status, AuthStatus.signedIn);
      expect(auth.member?.nickname, '무비러버');
      // 재시작은 restoreSession이 member를 채웠으므로 loadMember가 다시 부르지 않습니다.
      await auth.loadMember();
      expect(memberApi.fetchCount, 1);
    });

    test('AUTH401_3 on restore deletes the token and marks expiry', () async {
      storage.token = 'broken';
      memberApi.onFetch = () async => throw fakeInvalidToken('/v7/members/me');
      final auth = create();
      await auth.restoreSession();
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.sessionExpired, isTrue);
      expect(storage.token, isNull);
    });

    test('network failure on restore keeps the token for retry', () async {
      storage.token = 'valid';
      var calls = 0;
      memberApi.onFetch = () async {
        if (calls++ == 0) throw fakeDioError('/v7/members/me');
        return fakeMember;
      };
      final auth = create();
      await auth.restoreSession();
      expect(auth.status, AuthStatus.retryRequired);
      expect(storage.token, 'valid');
      expect(storage.log, isNot(contains('delete')));

      await auth.restoreSession();
      expect(auth.status, AuthStatus.signedIn);
    });

    test('storage read failure asks for retry', () async {
      storage.fail = true;
      final auth = create();
      await auth.restoreSession();
      expect(auth.status, AuthStatus.retryRequired);
      expect(auth.message, contains('인증 저장소'));
    });

    test('AUTH401_1 is a form error, not a session expiry', () async {
      authApi.onLogin = (_) async => throw fakeCommonError(
        '/v7/auth/login',
        401,
        'AUTH401_1',
        '이메일 또는 비밀번호가 올바르지 않습니다.',
      );
      final auth = create();
      await auth.restoreSession();
      await auth.login('movie@example.com', 'wrong');
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.message, '이메일 또는 비밀번호를 확인해 주세요.');
      expect(auth.sessionExpired, isFalse);
      expect(storage.log, isNot(contains('delete')));
    });

    test('login and storage failures use different messages', () async {
      final auth = create();
      await auth.restoreSession();
      authApi.onLogin = (_) async => throw fakeDioError('/v7/auth/login');
      await auth.login('a@b.com', 'p');
      final networkMessage = auth.message;

      authApi.onLogin = null;
      storage.fail = true;
      await auth.login('a@b.com', 'p');
      expect(auth.message, '로그인 정보를 안전하게 저장하지 못했어요.');
      expect(networkMessage, isNot(auth.message));
      expect(networkMessage, isNot('이메일 또는 비밀번호를 확인해 주세요.'));
    });

    test('login saves only the token, never the password', () async {
      final auth = create();
      await auth.restoreSession();
      await auth.login(' movie@example.com ', 'Secret123!');
      expect(auth.status, AuthStatus.signedIn);
      expect(storage.token, 'fresh-token');
      expect(storage.log.where((e) => e == 'save'), hasLength(1));
      expect(authApi.requests.single.toJson(), {
        'email': 'movie@example.com',
        'password': 'Secret123!',
      });
    });

    test('a login response arriving after logout is ignored', () async {
      final gate = Completer<LoginResult>();
      authApi.onLogin = (_) => gate.future;
      final auth = create();
      await auth.restoreSession();
      final logging = auth.login('a@b.com', 'p');
      await auth.logout(); // 응답 전에 세션을 정리한 상황입니다.

      gate.complete(
        const LoginResult(nickname: 'n', accessToken: 'late-token'),
      );
      await logging;
      expect(auth.status, AuthStatus.signedOut);
      expect(storage.token, isNull);
    });

    test(
      'many 401s clean up once, and an old 401 cannot end a new session',
      () async {
        storage.token = 'saved';
        final auth = create();
        await auth.restoreSession();
        final oldVersion = auth.sessionVersion;

        await Future.wait([
          auth.expireSession(sessionVersion: oldVersion),
          auth.expireSession(sessionVersion: oldVersion),
          auth.expireSession(sessionVersion: oldVersion),
        ]);
        expect(storage.log.where((e) => e == 'delete'), hasLength(1));

        await auth.login('a@b.com', 'p');
        expect(auth.status, AuthStatus.signedIn);
        // 이전 세션에서 늦게 도착한 401입니다.
        await auth.expireSession(sessionVersion: oldVersion);
        expect(auth.status, AuthStatus.signedIn);
        expect(storage.token, 'fresh-token');
      },
    );

    test('manual logout does not show the expiry notice', () async {
      storage.token = 'saved';
      final auth = create();
      await auth.restoreSession();
      await auth.logout();
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.sessionExpired, isFalse);
      expect(auth.member, isNull);
      expect(storage.token, isNull);
    });

    test('loadMember network failure keeps the session', () async {
      final auth = create();
      await auth.restoreSession();
      await auth.login('a@b.com', 'p');
      memberApi.onFetch = () async => throw fakeDioError('/v7/members/me');
      await auth.loadMember();
      expect(auth.status, AuthStatus.signedIn);
      expect(auth.memberStatus, MemberLoadStatus.error);
    });
  });

  group('Session ratings', () {
    late InMemoryTokenStorage storage;
    late FakeRatingApiService ratingApi;
    late AuthViewModel auth;
    late SessionRatingsViewModel ratings;

    setUp(() async {
      storage = InMemoryTokenStorage('saved');
      ratingApi = FakeRatingApiService();
      auth = AuthViewModel(
        FakeAuthApiService(),
        FakeMemberApiService(),
        storage,
      );
      ratings = SessionRatingsViewModel(ratingApi, auth);
      await auth.restoreSession();
    });

    test('create keeps the result object; logout clears it', () async {
      final created = await ratings.create(movieId: 550, score: 5);
      expect(ratings.ratingForMovie(550)?.ratingId, created.ratingId);
      expect(ratingApi.log, ['POST']); // 목록 GET 없이 result로 갱신합니다.

      await auth.logout();
      expect(ratings.ratings, isEmpty);
    });

    test('403 informs only and keeps the user signed in', () async {
      final created = await ratings.create(movieId: 550, score: 5);
      ratingApi.onUpdate = (_, _, _) async => throw fakeCommonError(
        '/v7/ratings/${created.ratingId}',
        403,
        'RATING403_1',
        '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.',
      );
      await expectLater(
        ratings.update(ratingId: created.ratingId, score: 1),
        throwsA(
          isA<RatingWriteFailure>()
              .having((f) => f.sessionExpired, 'sessionExpired', isFalse)
              .having((f) => f.message, 'message', contains('본인이 작성한')),
        ),
      );
      expect(auth.status, AuthStatus.signedIn);
      expect(ratings.ratings, hasLength(1));
    });

    test('RATING404_1 removes the stale card', () async {
      final created = await ratings.create(movieId: 550, score: 5);
      ratingApi.onDelete = (_) async => throw fakeCommonError(
        '/v7/ratings/${created.ratingId}',
        404,
        'RATING404_1',
        '해당 평점을 찾을 수 없습니다.',
      );
      await expectLater(
        ratings.delete(created.ratingId),
        throwsA(isA<RatingWriteFailure>()),
      );
      expect(ratings.ratings, isEmpty);
      expect(auth.status, AuthStatus.signedIn);
    });

    test('RATING409_1 tells the user to check the existing record', () async {
      ratingApi.onCreate = (_) async => throw fakeCommonError(
        '/v7/ratings',
        409,
        'RATING409_1',
        '이미 이 영화에 평점을 남기셨습니다.',
      );
      await expectLater(
        ratings.create(movieId: 550, score: 5),
        throwsA(
          isA<RatingWriteFailure>().having(
            (f) => f.message,
            'message',
            contains('기존 기록을 확인'),
          ),
        ),
      );
      expect(auth.status, AuthStatus.signedIn);
    });

    test('AUTH401_4 expires the session', () async {
      ratingApi.onCreate = (_) async => throw fakeCommonError(
        '/v7/ratings',
        401,
        'AUTH401_4',
        '토큰이 만료되었습니다. 다시 로그인해주세요.',
      );
      await expectLater(
        ratings.create(movieId: 550, score: 5),
        throwsA(
          isA<RatingWriteFailure>().having(
            (f) => f.sessionExpired,
            'sessionExpired',
            isTrue,
          ),
        ),
      );
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.sessionExpired, isTrue);
      expect(storage.token, isNull);
    });

    test('a create response from the previous session is not kept', () async {
      final gate = Completer<void>();
      ratingApi.onCreate = (request) async {
        await gate.future;
        return fakeRating(1, request.movieId, request.score);
      };
      final pending = ratings.create(movieId: 550, score: 5);
      await auth.logout();
      await auth.login('a@b.com', 'p'); // 다른 세션으로 바뀐 상황입니다.
      gate.complete();

      await expectLater(pending, throwsA(isA<RatingWriteFailure>()));
      expect(ratings.ratings, isEmpty);
    });
  });

  group('App flow', () {
    testWidgets('restart: splash → GET me → home', (tester) async {
      useTallScreen(tester);
      final gate = Completer<void>();
      final app = TestApp(
        memberApi: FakeMemberApiService(
          onFetch: () async {
            await gate.future;
            return fakeMember;
          },
        ),
      );
      await tester.pumpWidget(app.build());
      await tester.pump();
      await tester.pump();
      // 검증이 끝날 때까지 Splash에 머뭅니다. 로그인·홈을 먼저 보여주지 않습니다.
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();
      expect(app.router.state.uri.path, '/home');
      // 재시작 경로는 restoreSession의 GET me 한 번만 부릅니다.
      expect(app.memberApi.fetchCount, 1);
    });

    testWidgets('restore network failure shows retry, then enters', (
      tester,
    ) async {
      var calls = 0;
      final app = await pumpApp(
        tester,
        app: TestApp(
          memberApi: FakeMemberApiService(
            onFetch: () async {
              if (calls++ == 0) throw fakeDioError('/v7/members/me');
              return fakeMember;
            },
          ),
        ),
      );
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
      expect(app.storage.token, 'saved-token');

      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(app.router.state.uri.path, '/home');
    });

    testWidgets('deep link waits for the session, then opens', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/my');
      expect(app.router.state.uri.path, '/my');
      expect(find.text('무비러버'), findsOneWidget);
    });

    testWidgets('logged out: protected paths go to login', (tester) async {
      final app = await pumpApp(
        tester,
        app: TestApp(token: null),
        initialLocation: '/my/ratings',
      );
      expect(app.router.state.uri.path, '/login');

      for (final path in ['/home', '/my', '/movies/550', '/my/profile/edit']) {
        app.router.go(path);
        await tester.pumpAndSettle();
        expect(app.router.state.uri.path, '/login', reason: path);
      }
      // 회원가입은 공개 화면입니다.
      app.router.go('/signup');
      await tester.pumpAndSettle();
      expect(app.router.state.uri.path, '/signup');
    });

    testWidgets('login failure stays on the form; success opens home', (
      tester,
    ) async {
      final authApi = FakeAuthApiService(
        onLogin: (request) async {
          if (request.password != 'Right123!') {
            throw fakeCommonError(
              '/v7/auth/login',
              401,
              'AUTH401_1',
              '이메일 또는 비밀번호가 올바르지 않습니다.',
            );
          }
          return const LoginResult(nickname: '무비러버', accessToken: 'jwt');
        },
      );
      final app = await pumpApp(
        tester,
        app: TestApp(token: null, authApi: authApi),
      );
      final fields = find.byType(TextFormField);

      // 빈 값은 요청 전에 막습니다.
      await tester.tap(loginButton());
      await tester.pumpAndSettle();
      expect(find.text('이메일을 입력해 주세요.'), findsOneWidget);
      expect(authApi.requests, isEmpty);

      await tester.enterText(fields.at(0), 'movie@example.com');
      await tester.enterText(fields.at(1), 'wrong');
      await tester.tap(loginButton());
      await tester.pumpAndSettle();
      expect(find.text('이메일 또는 비밀번호를 확인해 주세요.'), findsOneWidget);
      expect(find.text(expiredText), findsNothing);
      expect(app.router.state.uri.path, '/login');

      await tester.enterText(fields.at(1), 'Right123!');
      await tester.tap(loginButton());
      await tester.pumpAndSettle();
      expect(app.router.state.uri.path, '/home');
      expect(app.storage.token, 'jwt');
      // MainNavigationShell이 내 정보를 한 번 불러옵니다.
      expect(app.memberApi.fetchCount, 1);

      // 홈을 거치지 않아도 마이페이지에 닉네임이 보입니다.
      await tester.tap(find.text('마이'));
      await tester.pumpAndSettle();
      expect(find.text('무비러버'), findsOneWidget);
      expect(find.text('movie@example.com'), findsOneWidget);
      expect(app.memberApi.fetchCount, 1);
    });

    testWidgets('login button is disabled while requesting', (tester) async {
      final gate = Completer<LoginResult>();
      final app = await pumpApp(
        tester,
        app: TestApp(
          token: null,
          authApi: FakeAuthApiService(onLogin: (_) => gate.future),
        ),
      );
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'movie@example.com');
      await tester.enterText(fields.at(1), 'p');
      await tester.tap(loginButton());
      await tester.pump();

      final button = tester.widget<MovieLogButton>(loginButton());
      expect(button.isLoading, isTrue);
      expect(tester.widget<TextFormField>(fields.at(0)).enabled, isFalse);
      await tester.tap(loginButton(), warnIfMissed: false);
      expect(app.authApi.requests, hasLength(1));

      gate.complete(const LoginResult(nickname: 'n', accessToken: 't'));
      await tester.pumpAndSettle();
    });

    testWidgets('logout clears the session and blocks protected screens', (
      tester,
    ) async {
      final app = await pumpApp(tester, initialLocation: '/my');
      await tester.tap(find.widgetWithText(TextButton, '로그아웃'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('로그아웃'),
        ),
      );
      await tester.pumpAndSettle();

      expect(app.router.state.uri.path, '/login');
      expect(app.storage.token, isNull);
      // 직접 로그아웃은 만료 안내를 띄우지 않습니다.
      expect(find.text(expiredText), findsNothing);

      app.router.go('/my');
      await tester.pumpAndSettle();
      expect(app.router.state.uri.path, '/login');
    });

    testWidgets('expired token on a protected request → login + notice', (
      tester,
    ) async {
      final app = await pumpApp(tester, initialLocation: '/my');
      app.memberApi.onFetch = () async =>
          throw fakeInvalidToken('/v7/members/me');

      final refresh = find.text('내 정보 새로고침');
      await tester.ensureVisible(refresh);
      await tester.tap(refresh);
      await tester.pumpAndSettle();

      expect(app.router.state.uri.path, '/login');
      expect(find.text(expiredText), findsOneWidget);
      expect(app.storage.token, isNull);
    });

    testWidgets('expired token on restart → login + notice', (tester) async {
      final app = await pumpApp(
        tester,
        app: TestApp(
          memberApi: FakeMemberApiService(
            onFetch: () async => throw fakeInvalidToken('/v7/members/me'),
          ),
        ),
      );
      expect(app.router.state.uri.path, '/login');
      expect(find.text(expiredText), findsOneWidget);
    });

    testWidgets('signup success goes to login with the email filled', (
      tester,
    ) async {
      final app = await pumpApp(
        tester,
        app: TestApp(token: null),
        initialLocation: '/signup',
      );
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '영화광');
      await tester.enterText(fields.at(1), 'new@example.com');
      await tester.enterText(fields.at(2), 'Umc1234!');
      await tester.pump();
      await tester.tap(find.text('중복 확인').at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('중복 확인').at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('필수 약관에 동의합니다'));
      await tester.pump();
      await tester.tap(find.text('가입하기'));
      await tester.pumpAndSettle();

      expect(app.router.state.uri.path, '/login');
      expect(find.text('회원가입이 완료됐어요. 로그인해 주세요.'), findsOneWidget);
      expect(find.text('new@example.com'), findsOneWidget);
      // 가입은 인증이 아니므로 토큰이 생기지 않습니다.
      expect(app.storage.token, isNull);
    });
  });

  group('Edit profile', () {
    Future<TestApp> openEdit(WidgetTester tester, {TestApp? app}) async {
      final testApp = await pumpApp(tester, app: app, initialLocation: '/my');
      await tester.tap(find.text('프로필 수정'));
      await tester.pumpAndSettle();
      expect(testApp.router.state.uri.path, '/my/profile/edit');
      return testApp;
    }

    Finder nicknameField() => find.byType(TextField).last;

    testWidgets('success replaces member and returns to my page', (
      tester,
    ) async {
      final app = await openEdit(tester);
      // 이메일은 읽기 전용입니다.
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField)).enabled,
        isFalse,
      );

      await tester.enterText(nicknameField(), '시네필');
      await tester.tap(find.widgetWithText(MovieLogButton, '저장'));
      await tester.pumpAndSettle();

      expect(app.router.state.uri.path, '/my');
      expect(find.text('프로필을 수정했어요.'), findsOneWidget);
      expect(find.text('시네필'), findsOneWidget);
      expect(app.memberApi.updates, ['시네필']);
      // 수정 응답으로 교체하므로 GET me를 다시 부르지 않습니다.
      expect(app.memberApi.fetchCount, 1);
    });

    testWidgets('409 shows under the field and keeps the input', (
      tester,
    ) async {
      final app = await openEdit(
        tester,
        app: TestApp(
          memberApi: FakeMemberApiService(
            onUpdate: (_) async => throw fakeCommonError(
              '/v7/members/me',
              409,
              'MEMBER409_1',
              '이미 사용 중인 닉네임입니다.',
            ),
          ),
        ),
      );
      await tester.enterText(nicknameField(), '영화광');
      await tester.tap(find.widgetWithText(MovieLogButton, '저장'));
      await tester.pumpAndSettle();

      expect(app.router.state.uri.path, '/my/profile/edit');
      expect(find.text('이미 사용 중인 닉네임이에요.'), findsOneWidget);
      expect(find.text('영화광'), findsOneWidget);
      expect(app.storage.token, 'saved-token');
    });

    testWidgets('length is checked before sending; same name sends nothing', (
      tester,
    ) async {
      final app = await openEdit(tester);
      await tester.enterText(nicknameField(), '가');
      await tester.tap(find.widgetWithText(MovieLogButton, '저장'));
      await tester.pumpAndSettle();
      expect(find.text('닉네임은 2~12자로 입력해 주세요.'), findsOneWidget);

      await tester.enterText(nicknameField(), '무비러버');
      await tester.tap(find.widgetWithText(MovieLogButton, '저장'));
      await tester.pumpAndSettle();
      expect(app.router.state.uri.path, '/my');
      expect(app.memberApi.updates, isEmpty);
    });

    testWidgets('network failure keeps the session and shows a snackbar', (
      tester,
    ) async {
      final app = await openEdit(
        tester,
        app: TestApp(
          memberApi: FakeMemberApiService(
            onUpdate: (_) async => throw fakeDioError('/v7/members/me'),
          ),
        ),
      );
      await tester.enterText(nicknameField(), '시네필');
      await tester.tap(find.widgetWithText(MovieLogButton, '저장'));
      await tester.pumpAndSettle();
      expect(find.text('네트워크 상태를 확인하고 다시 시도해 주세요.'), findsOneWidget);
      expect(app.router.state.uri.path, '/my/profile/edit');
      expect(app.storage.token, 'saved-token');
    });
  });

  group('Token rating flow on movie detail', () {
    TestApp detailApp({FakeRatingApiService? ratingApi}) => TestApp(
      movieService: FakeMovieLookupService(
        movies: {550: fakeMovie(550, '파이트 클럽')},
      ),
      ratingApi: ratingApi,
    );

    testWidgets('create → edit → delete with the result object', (
      tester,
    ) async {
      final app = await pumpApp(
        tester,
        app: detailApp(),
        initialLocation: '/movies/550',
      );

      // 등록
      await tester.tap(find.text('평점 남기기'));
      await tester.pumpAndSettle();
      await tester.tap(emptyStars().at(3));
      await tester.enterText(commentField(), '다시 봐도 좋아요');
      await tester.tap(dialogButton('확인'));
      await tester.pumpAndSettle();
      expect(find.text('평점을 등록했습니다.'), findsOneWidget);
      expect(find.text('내 평점 4점'), findsOneWidget);
      expect(find.text('평점 수정'), findsOneWidget);
      expect(app.ratingApi.creates.single.toJson(), {
        'movieId': 550,
        'score': 4,
        'comment': '다시 봐도 좋아요',
      });

      // 수정: 기존 별점·코멘트가 채워진 채 열리고, 둘 다 함께 보냅니다.
      await tester.tap(find.text('수정'));
      await tester.pumpAndSettle();
      expect(filledStars(), findsNWidgets(4));
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('다시 봐도 좋아요'),
        ),
        findsOneWidget,
      );
      await tester.tap(filledStars().at(1));
      await tester.tap(dialogButton('확인'));
      await tester.pumpAndSettle();
      expect(app.ratingApi.updates.single, (100, 2, '다시 봐도 좋아요'));
      expect(find.text('내 평점 2점'), findsOneWidget);

      // 삭제 (떠 있는 Snackbar가 사라진 뒤 카드의 삭제 버튼을 누릅니다)
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('삭제'));
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('삭제'));
      await tester.pumpAndSettle();
      expect(find.text('평점을 삭제했습니다.'), findsOneWidget);
      expect(find.textContaining('내 평점'), findsNothing);
      expect(find.text('평점 남기기'), findsOneWidget);
      expect(app.ratingApi.log, ['POST', 'PATCH 100', 'DELETE 100']);
    });

    testWidgets('401 while saving closes the flow and goes to login', (
      tester,
    ) async {
      final ratingApi = FakeRatingApiService(
        onCreate: (_) async => throw fakeInvalidToken('/v7/ratings'),
      );
      final app = await pumpApp(
        tester,
        app: detailApp(ratingApi: ratingApi),
        initialLocation: '/movies/550',
      );
      await tester.tap(find.text('평점 남기기'));
      await tester.pumpAndSettle();
      await tester.tap(emptyStars().last);
      await tester.pump();
      await tester.tap(dialogButton('확인'));
      await tester.pumpAndSettle();

      expect(app.router.state.uri.path, '/login');
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(expiredText), findsOneWidget);
    });

    testWidgets('409 keeps the dialog and the user signed in', (tester) async {
      final ratingApi = FakeRatingApiService(
        onCreate: (_) async => throw fakeCommonError(
          '/v7/ratings',
          409,
          'RATING409_1',
          '이미 이 영화에 평점을 남기셨습니다.',
        ),
      );
      final app = await pumpApp(
        tester,
        app: detailApp(ratingApi: ratingApi),
        initialLocation: '/movies/550',
      );
      await tester.tap(find.text('평점 남기기'));
      await tester.pumpAndSettle();
      await tester.tap(emptyStars().last);
      await tester.enterText(commentField(), '최고');
      await tester.tap(dialogButton('확인'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('기존 기록을 확인'), findsOneWidget);
      expect(find.text('최고'), findsOneWidget);
      expect(app.router.state.uri.path, '/movies/550');
    });
  });
}

/// 요청 method·경로·Authorization·body를 기록하고 정해진 응답을 돌려주는 Dio Adapter입니다.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.reply);

  final (int, String) Function(RequestOptions request) reply;
  final requests = <(String, String)>[];
  final authHeaders = <String?>[];
  final bodies = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add((options.method, options.uri.path));
    authHeaders.add(options.headers['Authorization'] as String?);
    if (requestStream != null) {
      final chunks = await requestStream.toList();
      bodies.add(utf8.decode(chunks.expand((chunk) => chunk).toList()));
    } else {
      bodies.add('');
    }
    final (status, body) = reply(options);
    return ResponseBody.fromBytes(
      utf8.encode(body),
      status,
      headers: {
        if (body.isNotEmpty)
          Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
