import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/data/movie_preferences.dart';
import 'package:movielog/main.dart';
import 'package:provider/provider.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/session_ratings.dart';

import 'fake_movie_log_services.dart';
import 'fake_tmdb_movie_service.dart';

/// 테스트 앱 + 안에 넣은 Fake들
class TestApp {
  TestApp({
    required this.tester,
    required this.tokenStorage,
    required this.authApi,
    required this.memberApi,
    required this.ratingApi,
    required this.signUpService,
    required this.movieService,
  });

  final WidgetTester tester;
  final FakeTokenStorage tokenStorage;
  final FakeAuthApiService authApi;
  final FakeMemberApiService memberApi;
  final FakeRatingApiService ratingApi;
  final FakeSignUpService signUpService;
  final FakeTmdbMovieService movieService;

  BuildContext get _context => tester.element(find.byType(Navigator).first);

  GoRouter get router => GoRouter.of(_context);

  String get location =>
      router.routerDelegate.currentConfiguration.uri.toString();

  AuthViewModel get auth => _context.read<AuthViewModel>();

  SessionRatings get sessionRatings => _context.read<SessionRatings>();
}

/// 폰 크기로 앱 띄움
/// signedIn true면 저장된 토큰으로 시작 → 세션 복원(GET me) 거쳐 location 도착
Future<TestApp> pumpApp(
  WidgetTester tester, {
  String location = '/start',
  bool signedIn = true,
  FakeTokenStorage? tokenStorage,
  FakeAuthApiService? authApi,
  FakeMemberApiService? memberApi,
  FakeRatingApiService? ratingApi,
  FakeSignUpService? signUpService,
  FakeTmdbMovieService? movieService,

  /// null이면 화면 크기 안 건드림 (테스트가 먼저 정한 크기 유지)
  Size? size = const Size(400, 900),
  bool settle = true,
}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  final app = TestApp(
    tester: tester,
    tokenStorage:
        tokenStorage ?? FakeTokenStorage(signedIn ? 'saved-token' : null),
    authApi: authApi ?? FakeAuthApiService(),
    memberApi: memberApi ?? FakeMemberApiService(),
    ratingApi: ratingApi ?? FakeRatingApiService(),
    signUpService: signUpService ?? FakeSignUpService(),
    movieService: movieService ?? FakeTmdbMovieService(),
  );
  await tester.pumpWidget(
    MovieLogApp(
      movieService: app.movieService,
      signUpService: app.signUpService,
      authApiService: app.authApi,
      memberApiService: app.memberApi,
      ratingApiService: app.ratingApi,
      tokenStorage: app.tokenStorage,
      preferences: MoviePreferences(),
      initialLocation: location,
    ),
  );
  if (!settle) return app;
  await tester.pumpAndSettle();
  // 세션 복원 끝나면 Router가 /home으로 보냄 → 원하는 화면으로 다시 이동
  if (signedIn && location != '/start' && app.location != location) {
    app.router.go(location);
    await tester.pumpAndSettle();
  }
  return app;
}
