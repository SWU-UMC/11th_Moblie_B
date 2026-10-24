import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:movielog/data/movie_preferences.dart';
import 'package:movielog/main.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/router/app_routes.dart';
import 'package:movielog/widgets/home/popular_movie_list.dart';
import 'package:movielog/widgets/movie/genre_chip_bar.dart';
import 'package:movielog/widgets/movie/movie_poster_card.dart';
import 'package:movielog/widgets/movie_list/movie_grid.dart';
import 'package:movielog/widgets/movie_list/movie_list_error.dart';
import 'package:movielog/widgets/movie_list/retry_dialog.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_tmdb_movie_service.dart';

/// 휴대폰 크기 화면에서 [location]부터 시작합니다. TMDB 대신 Fake Service를 씁니다.
Future<GoRouter> _pumpApp(
  WidgetTester tester,
  String location, {
  FakeTmdbMovieService? service,
  Size size = const Size(400, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = AppRouter.createRouter(
    initialLocation: location,
    preferences: MoviePreferences(),
  );
  await tester.pumpWidget(
    MovieLogApp(
      router: router,
      movieService: service ?? FakeTmdbMovieService(),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

Finder _navDestination(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

Finder _chip(String label) => find.widgetWithText(ChoiceChip, label);

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('시작 → 회원가입 → 홈으로 이동하고, 회원가입·홈에서는 뒤로 갈 수 없다', (tester) async {
    final router = await _pumpApp(tester, AppRoutes.start);

    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();
    expect(_location(router), AppRoutes.register);
    expect(router.canPop(), isFalse);

    await tester.enterText(
      find.widgetWithText(TextFormField, '닉네임을 입력해주세요'),
      '무비러버',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '이메일 주소를 입력해주세요'),
      'movie@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '비밀번호를 입력해주세요'),
      'password123',
    );
    await tester.tap(find.text('필수 약관에 동의합니다'));
    await tester.pump();
    await tester.tap(find.text('가입하기'));
    await tester.pumpAndSettle();

    expect(_location(router), AppRoutes.home);
    expect(router.canPop(), isFalse);
    expect(find.text('오늘은 어떤\n영화를 볼까요?'), findsOneWidget);
  });

  testWidgets('홈은 Popular 앞 5개를 보여주고, 추천 카드에서 상세로 push한다', (tester) async {
    final router = await _pumpApp(tester, AppRoutes.home);

    // 1위는 추천 카드, 인기 영화 가로 목록은 Popular 20개 중 앞 5개만
    expect(find.text('인기 1위'), findsOneWidget);
    final popular = tester.widget<PopularMovieList>(
      find.byType(PopularMovieList),
    );
    expect(popular.movies.map((m) => m.id), [1, 2, 3, 4, 5]);

    await tester.tap(find.text('상세보기'));
    await tester.pumpAndSettle();
    expect(router.canPop(), isTrue);
    expect(find.text('Cinema Archive'), findsOneWidget);

    await tester.tap(find.byTooltip('뒤로 가기'));
    await tester.pumpAndSettle();
    expect(router.canPop(), isFalse);
  });

  testWidgets('홈 Popular 요청이 실패하면 Error 화면과 다시 시도', (tester) async {
    final service = FakeTmdbMovieService()..failPopular = true;
    await _pumpApp(tester, AppRoutes.home, service: service);

    expect(find.text('인기 영화를 불러오지 못했어요.'), findsOneWidget);
    service.failPopular = false;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('인기 1위'), findsOneWidget);
  });

  testWidgets('NavigationBar로 홈·영화·마이 탭을 전환한다', (tester) async {
    final router = await _pumpApp(tester, AppRoutes.home);

    await tester.tap(_navDestination('영화'));
    await tester.pumpAndSettle();
    expect(_location(router), AppRoutes.movies);
    expect(find.byType(MovieGrid), findsOneWidget);

    await tester.tap(_navDestination('마이'));
    await tester.pumpAndSettle();
    expect(find.text('내 프로필'), findsOneWidget);
  });

  testWidgets('영화 목록: Genre API로 Chip을 만들고, 카드를 누르면 TMDB id로 상세 이동', (
    tester,
  ) async {
    final router = await _pumpApp(tester, AppRoutes.movies);

    for (final label in ['전체', '액션', '드라마', 'SF']) {
      expect(_chip(label), findsOneWidget);
    }

    await tester.tap(find.widgetWithText(MoviePosterCard, '영화 2'));
    await tester.pumpAndSettle();
    expect(router.canPop(), isTrue);
    expect(find.text('영화 2'), findsOneWidget);
    expect(find.text('영화 2 줄거리'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(MovieGrid), findsOneWidget);
  });

  testWidgets('장르 Chip을 누르면 with_genres로 page 1부터 다시 요청한다', (tester) async {
    final service = FakeTmdbMovieService();
    await _pumpApp(tester, AppRoutes.movies, service: service);
    service.discoverCalls.clear();

    await tester.tap(_chip('SF'));
    await tester.pumpAndSettle();

    expect(service.discoverCalls.first.page, 1);
    expect(service.discoverCalls.first.genreIds, [878]);
    expect(find.byType(MoviePosterCard), findsWidgets);
    expect(find.widgetWithText(MoviePosterCard, '영화 1'), findsNothing);
  });

  testWidgets('영화를 불러오는 중에는 장르 Chip이 비활성화된다', (tester) async {
    final service = FakeTmdbMovieService();
    await _pumpApp(tester, AppRoutes.movies, service: service);

    service.discoverGate = Completer();
    await tester.tap(_chip('액션'));
    await tester.pump();

    final bar = tester.widget<GenreChipBar>(find.byType(GenreChipBar));
    expect(bar.enabled, isFalse);
    service.discoverCalls.clear();
    await tester.tap(_chip('드라마'), warnIfMissed: false);
    await tester.pump();
    expect(service.discoverCalls, isEmpty);

    service.discoverGate!.complete();
    await tester.pumpAndSettle();
    expect(
      tester.widget<GenreChipBar>(find.byType(GenreChipBar)).enabled,
      isTrue,
    );
  });

  testWidgets('BottomSheet에서 여러 장르를 고르면 id 목록으로 요청한다', (tester) async {
    final service = FakeTmdbMovieService();
    await _pumpApp(tester, AppRoutes.movies, service: service);
    service.discoverCalls.clear();

    await tester.tap(find.byTooltip('장르 필터'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, '액션'));
    await tester.tap(find.widgetWithText(CheckboxListTile, 'SF'));
    await tester.pump();
    expect(service.discoverCalls, isEmpty); // 확인 전에는 요청하지 않음

    await tester.tap(find.widgetWithText(ElevatedButton, '확인'));
    await tester.pumpAndSettle();
    expect(service.discoverCalls.first.genreIds, [28, 878]);
  });

  testWidgets('처음부터 실패하면 Error 화면, 다시 시도하면 목록이 나온다', (tester) async {
    final service = FakeTmdbMovieService()..failDiscover = true;
    await _pumpApp(tester, AppRoutes.movies, service: service);

    expect(find.byType(MovieListError), findsOneWidget);
    service.failDiscover = false;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.byType(MovieGrid), findsOneWidget);
  });

  testWidgets('새로고침이 실패하면 목록을 유지한 채 재시도 Dialog를 띄운다', (tester) async {
    final service = FakeTmdbMovieService();
    await _pumpApp(tester, AppRoutes.movies, service: service);

    service.failDiscover = true;
    await tester.fling(find.byType(MovieGrid), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(find.byType(RetryDialog), findsOneWidget);
    expect(find.text('영화를 불러오지 못했어요'), findsOneWidget);
    expect(find.byType(MovieGrid), findsOneWidget);

    service.failDiscover = false;
    service.discoverCalls.clear();
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();

    expect(find.byType(RetryDialog), findsNothing);
    expect(service.discoverCalls.first.page, 1);
    expect(find.byType(MovieGrid), findsOneWidget);
  });

  testWidgets('상세: 평점 Dialog와 즐겨찾기 Snackbar', (tester) async {
    await _pumpApp(tester, AppRoutes.movieDetailOf(3));
    expect(find.text('영화 3'), findsOneWidget);

    await tester.tap(find.text('평점 남기기'));
    await tester.pumpAndSettle();
    final lastStar = find.byIcon(Icons.star_rounded).last;
    await tester.tapAt(tester.getTopRight(lastStar) + const Offset(-2, 10));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, '확인'));
    await tester.pumpAndSettle();
    expect(find.text('평점 5.0점을 남겼어요.'), findsOneWidget);

    await tester.tap(find.text('즐겨찾기'));
    await tester.pumpAndSettle();
    expect(find.text('영화 3을(를) 즐겨찾기에 추가했어요.'), findsOneWidget);
  });

  testWidgets('없는 영화 id로 들어오면 안내 문구를 보여준다', (tester) async {
    await _pumpApp(tester, '/movies/999');
    expect(find.text('영화를 찾을 수 없어요'), findsOneWidget);
  });

  testWidgets('작은 휴대폰 화면(360x640)에서 모든 탭과 상세에 Overflow가 없다', (tester) async {
    for (final location in [
      AppRoutes.home,
      AppRoutes.movies,
      AppRoutes.my,
      AppRoutes.movieDetailOf(1),
    ]) {
      await _pumpApp(tester, location, size: const Size(360, 640));
      expect(tester.takeException(), isNull, reason: location);
    }
  });
}
