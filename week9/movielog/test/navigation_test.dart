import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:movielog/router/app_routes.dart';
import 'package:movielog/screens/movie_search_screen.dart';
import 'package:movielog/screens/sign_up_screen.dart';
import 'package:movielog/widgets/home/popular_movie_list.dart';
import 'package:movielog/widgets/movie/movie_poster_card.dart';
import 'package:movielog/widgets/movie_list/movie_grid.dart';
import 'package:movielog/widgets/movie_list/movie_list_error.dart';
import 'package:movielog/widgets/movielog_button.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/app_harness.dart';
import 'support/fake_movie_log_services.dart';
import 'support/fake_tmdb_movie_service.dart';

/// 로그인된 상태로 location에서 시작 (TMDB·워크북 서버 Fake)
Future<GoRouter> _pumpApp(
  WidgetTester tester,
  String location, {
  FakeTmdbMovieService? service,
  Size size = const Size(400, 900),
}) async {
  final app = await pumpApp(
    tester,
    location: location,
    movieService: service,
    size: size,
  );
  return app.router;
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

  testWidgets('로그인 → 회원가입 → 가입하면 로그인으로 돌아와 이메일이 채워진다', (tester) async {
    final app = await pumpApp(tester, signedIn: false);
    expect(app.location, AppRoutes.login);

    await tester.tap(find.text('회원가입'));
    await tester.pumpAndSettle();
    expect(find.byType(SignUpScreen), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, '닉네임을 입력해주세요'),
      '제로',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '이메일 주소를 입력해주세요'),
      'new@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '비밀번호를 입력해주세요'),
      'Password1!',
    );
    await tester.pump();
    final checkButtons = find.widgetWithText(MovieLogButton, '중복 확인');
    await tester.tap(checkButtons.at(0));
    await tester.tap(checkButtons.at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('필수 약관에 동의합니다'));
    await tester.pump();
    await tester.tap(find.text('가입하기'));
    await tester.pumpAndSettle();

    // 8주차: 가입만으로는 토큰 없음 → 로그인 화면으로, 이메일 채워둠
    expect(app.location, AppRoutes.login);
    expect(find.text('new@example.com'), findsOneWidget);
    expect(app.auth.status.name, 'signedOut');
  });

  testWidgets('홈은 Popular 앞 5개를 보여주고, 추천 카드에서 상세로 push한다', (tester) async {
    final router = await _pumpApp(tester, AppRoutes.home);

    // 1위는 추천 카드, 가로 목록은 앞 5개
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

  testWidgets('요청 중에 장르를 바꾸면 이전 장르의 늦은 응답은 화면에 안 섞인다', (tester) async {
    final service = FakeTmdbMovieService();
    await _pumpApp(tester, AppRoutes.movies, service: service);

    // 액션(짝수 id) 요청이 끝나기 전에 드라마(홀수 id)로 바꿈
    service.discoverGate = Completer();
    await tester.tap(_chip('액션'));
    await tester.pump();
    await tester.tap(_chip('드라마'));
    await tester.pump();
    service.discoverGate!.complete();
    service.discoverGate = null;
    await tester.pumpAndSettle();

    expect(find.widgetWithText(MoviePosterCard, '영화 1'), findsOneWidget);
    expect(find.widgetWithText(MoviePosterCard, '영화 2'), findsNothing);
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
    expect(service.discoverCalls, isEmpty); // 확인 누르기 전엔 요청 X

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

  testWidgets('더 보기: 다음 page 실패하면 기존 카드 유지 + 같은 page 재시도, 끝이면 숨김', (
    tester,
  ) async {
    final service = FakeTmdbMovieService()..failDiscoverPages.add(2);
    await _pumpApp(tester, AppRoutes.movies, service: service);
    expect(service.discoverCalls.map((c) => c.page), [1]);

    // 끝까지 내리면 (Challenge 무한 스크롤) 2 page 자동 요청 → 실패
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('movie-page-footer-button')),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('추가 영화 조회에 실패했습니다.'), findsOneWidget);
    expect(find.text('다음 페이지 다시 시도'), findsOneWidget);
    expect(find.byType(MoviePosterCard), findsWidgets); // 기존 카드 그대로
    expect(service.discoverCalls.map((c) => c.page), [1, 2]);

    // 실패 뒤엔 스크롤로 자동 재요청 안 함 → 버튼으로 같은 page 2
    service.failDiscoverPages.clear();
    await tester.tap(find.text('다음 페이지 다시 시도'));
    await tester.pumpAndSettle();
    expect(service.discoverCalls.map((c) => c.page).take(3), [1, 2, 2]);

    // 45개 / 20개씩 → 3 page가 마지막
    await tester.scrollUntilVisible(
      find.text('모든 영화를 확인했습니다.'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('모든 영화를 확인했습니다.'), findsOneWidget);
    expect(find.text('더 보기'), findsNothing);
    expect(service.discoverCalls.last.page, 3);
  });

  testWidgets('영화 목록 AppBar 검색 아이콘 → 검색 화면(하단 바 없음)', (tester) async {
    final router = await _pumpApp(tester, AppRoutes.movies);

    await tester.tap(find.byKey(const ValueKey('movie-search-button')));
    await tester.pumpAndSettle();
    expect(router.canPop(), isTrue);
    expect(find.byType(MovieSearchScreen), findsOneWidget);
    expect(find.text('영화 검색'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('상세: 로그인 상태면 평점 남기기 활성화, 북마크는 서버 저장 후 Snackbar', (tester) async {
    final favorites = FakeFavoriteApiService();
    final app = await pumpApp(
      tester,
      location: AppRoutes.movieDetailOf(3),
      favoriteApi: favorites,
    );
    expect(find.text('영화 3'), findsOneWidget);
    expect(favorites.checkCalls, [3]); // 상세 진입 때 여부 한 번

    final rate = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('평점 남기기'),
        matching: find.byWidgetPredicate((w) => w is ElevatedButton),
      ),
    );
    expect(rate.onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('favorite-button')));
    await tester.pumpAndSettle();
    expect(find.text('즐겨찾기에 추가했습니다.'), findsOneWidget);
    expect(favorites.server.keys, [3]);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(app.location, AppRoutes.movieDetailOf(3));
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
      AppRoutes.movieSearch,
      AppRoutes.myFavorites,
    ]) {
      await _pumpApp(tester, location, size: const Size(360, 640));
      expect(tester.takeException(), isNull, reason: location);
    }
  });
}
