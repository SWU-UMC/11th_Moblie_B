import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/router/app_routes.dart';
import 'package:movielog/screens/favorites_screen.dart';
import 'package:movielog/screens/movie_detail_screen.dart';
import 'package:movielog/screens/movie_search_screen.dart';
import 'package:movielog/widgets/movie/movie_summary_card.dart';
import 'package:movielog/widgets/movielog_button.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/app_harness.dart';
import 'support/fake_movie_log_services.dart';
import 'support/fake_tmdb_movie_service.dart';

Finder _favoriteButton() => find.byKey(const ValueKey('favorite-button'));

/// Dialog 별점에서 n번째 별 탭 (1~5)
Future<void> _tapStar(WidgetTester tester, int n) async {
  final stars = find.descendant(
    of: find.byType(Dialog),
    matching: find.byWidgetPredicate(
      (w) => w is Icon && (w.icon == Icons.star || w.icon == Icons.star_border),
    ),
  );
  await tester.tap(stars.at(n - 1));
  await tester.pump();
}

Future<void> _back(WidgetTester tester) async {
  await tester.tap(find.byTooltip('뒤로 가기'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('마이페이지 → 내 즐겨찾기', () {
    testWidgets('평점 행 아래 "내 즐겨찾기" → 목록 → 상세에서 해제 → 뒤로가면 사라짐', (tester) async {
      final favorites = FakeFavoriteApiService()
        ..seed(1)
        ..seed(2);
      final app = await pumpApp(
        tester,
        location: AppRoutes.my,
        favoriteApi: favorites,
      );

      final ratingsY = tester.getTopLeft(find.text('내가 등록한 평점')).dy;
      final favoritesY = tester.getTopLeft(find.text('내 즐겨찾기')).dy;
      expect(favoritesY, greaterThan(ratingsY));

      await tester.tap(find.text('내 즐겨찾기'));
      await tester.pumpAndSettle();
      expect(find.byType(FavoritesScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing); // 하단 바 없음
      expect(find.widgetWithText(MovieSummaryCard, '영화 1'), findsOneWidget);
      expect(find.widgetWithText(MovieSummaryCard, '영화 2'), findsOneWidget);
      expect(find.text('즐겨찾기한 영화'), findsNWidgets(2));

      await tester.tap(find.widgetWithText(MovieSummaryCard, '영화 1'));
      await tester.pumpAndSettle();
      expect(find.byType(MovieDetailScreen), findsOneWidget);
      expect(find.byIcon(Icons.bookmark), findsOneWidget);

      await tester.tap(_favoriteButton());
      await tester.pumpAndSettle();
      expect(find.text('즐겨찾기에서 삭제했습니다.'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);

      final listCallsBefore = favorites.listCalls;
      await _back(tester);
      expect(find.byType(FavoritesScreen), findsOneWidget);
      expect(favorites.listCalls, listCallsBefore + 1); // 돌아오면 다시 조회
      expect(find.widgetWithText(MovieSummaryCard, '영화 1'), findsNothing);
      expect(find.widgetWithText(MovieSummaryCard, '영화 2'), findsOneWidget);
      expect(app.router.canPop(), isTrue); // push로 열린 화면
    });

    testWidgets('빈 목록 / 조회 오류 + 다시 시도를 따로 보여줌', (tester) async {
      final favorites = FakeFavoriteApiService()
        ..listError = fakeHttpError('/v8/favorites');
      await pumpApp(
        tester,
        location: AppRoutes.myFavorites,
        favoriteApi: favorites,
      );
      expect(find.text('즐겨찾기를 불러오지 못했습니다.'), findsOneWidget);

      favorites.listError = null;
      await tester.tap(find.widgetWithText(MovieLogButton, '다시 시도'));
      await tester.pumpAndSettle();
      expect(find.text('아직 즐겨찾기한 영화가 없습니다.'), findsOneWidget);
      expect(find.text('영화 상세에서 북마크를 눌러보세요.'), findsOneWidget);
    });

    testWidgets('영화 정보 한 건 실패: placeholder + 그 카드만 다시 불러오기', (tester) async {
      final favorites = FakeFavoriteApiService()
        ..seed(1)
        ..seed(2);
      final movies = FakeTmdbMovieService()..failDetailIds.add(2);
      await pumpApp(
        tester,
        location: AppRoutes.myFavorites,
        favoriteApi: favorites,
        movieService: movies,
      );

      expect(find.widgetWithText(MovieSummaryCard, '영화 1'), findsOneWidget);
      expect(find.text('영화 #2'), findsOneWidget);
      expect(find.text('영화 정보를 불러오지 못했습니다.'), findsOneWidget);

      movies.failDetailIds.clear();
      await tester.tap(find.text('정보 다시 불러오기'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(MovieSummaryCard, '영화 2'), findsOneWidget);
      expect(find.text('영화 #2'), findsNothing);
    });

    testWidgets('로그아웃 → 다른 계정 로그인하면 이전 계정 즐겨찾기 안 보임', (tester) async {
      final favorites = FakeFavoriteApiService()..seed(1);
      final memberApi = FakeMemberApiService();
      final app = await pumpApp(
        tester,
        location: AppRoutes.myFavorites,
        favoriteApi: favorites,
        memberApi: memberApi,
      );
      expect(find.widgetWithText(MovieSummaryCard, '영화 1'), findsOneWidget);

      await app.auth.logout();
      await tester.pumpAndSettle();
      expect(app.location, AppRoutes.login);

      // 계정 B: 서버가 B의 즐겨찾기만 줌
      memberApi.member = fakeMember(nickname: '계정B', email: 'b@example.com');
      favorites.server.clear();
      favorites.seed(2);
      await tester.enterText(
        find.byKey(const Key('login-email')),
        'movie@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('login-password')),
        'Password1!',
      );
      await tester.tap(find.widgetWithText(MovieLogButton, '로그인'));
      await tester.pumpAndSettle();

      app.router.go(AppRoutes.myFavorites);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(MovieSummaryCard, '영화 1'), findsNothing);
      expect(find.widgetWithText(MovieSummaryCard, '영화 2'), findsOneWidget);
    });
  });

  group('영화 상세 북마크', () {
    testWidgets('요청 중엔 북마크 자리에만 인디케이터, 실패하면 이전 아이콘 + 안내', (tester) async {
      final favorites = FakeFavoriteApiService();
      await pumpApp(
        tester,
        location: AppRoutes.movieDetailOf(4),
        favoriteApi: favorites,
      );
      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);

      favorites
        ..writeError = fakeHttpError('/v8/favorites')
        ..writeGate = Completer();
      await tester.tap(_favoriteButton());
      await tester.pump();
      expect(
        find.descendant(
          of: _favoriteButton(),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      // 평점 남기기 버튼은 그대로 (전체 로딩 아님)
      expect(find.text('평점 남기기'), findsOneWidget);
      favorites.writeGate!.complete();
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
      expect(
        find.text('즐겨찾기에 추가하지 못했습니다. 다시 시도해 주세요.'),
        findsWidgets, // 박스 + Snackbar
      );
      expect(favorites.server, isEmpty);
    });

    testWidgets('즐겨찾기 요청이 AUTH401_4면 세션 정리하고 로그인 화면', (tester) async {
      final favorites = FakeFavoriteApiService();
      final app = await pumpApp(
        tester,
        location: AppRoutes.movieDetailOf(4),
        favoriteApi: favorites,
      );
      favorites.writeError = fakeExpiredError('/v8/favorites');
      await tester.tap(_favoriteButton());
      await tester.pumpAndSettle();
      expect(app.location, AppRoutes.login);
      expect(find.text('로그인이 만료됐어요. 다시 로그인해 주세요.'), findsOneWidget);
    });
  });

  group('Challenge: 평점 Dialog "즐겨찾기에도 추가"', () {
    testWidgets('즐겨찾기 안 한 영화: 체크 → movie-records 한 번 → Snackbar + 북마크 채워짐', (
      tester,
    ) async {
      final favorites = FakeFavoriteApiService();
      final app = await pumpApp(
        tester,
        location: AppRoutes.movieDetailOf(6),
        favoriteApi: favorites,
      );

      await tester.tap(find.text('평점 남기기'));
      await tester.pumpAndSettle();
      expect(find.text('즐겨찾기에도 추가'), findsOneWidget);

      await _tapStar(tester, 4);
      await tester.tap(find.byKey(const ValueKey('add-to-favorite')));
      await tester.pump();
      await tester.tap(find.widgetWithText(MovieLogButton, '확인'));
      await tester.pumpAndSettle();

      expect(find.text('평점을 저장했습니다.'), findsOneWidget);
      expect(app.ratingApi.recordCalls.single['addToFavorites'], isTrue);
      expect(favorites.server.keys, [6]);
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
    });

    testWidgets('이미 즐겨찾기한 영화면 체크박스 안 보이고 평점만 저장', (tester) async {
      final favorites = FakeFavoriteApiService()..seed(6);
      final app = await pumpApp(
        tester,
        location: AppRoutes.movieDetailOf(6),
        favoriteApi: favorites,
      );

      await tester.tap(find.text('평점 남기기'));
      await tester.pumpAndSettle();
      expect(find.text('즐겨찾기에도 추가'), findsNothing);

      await _tapStar(tester, 5);
      await tester.tap(find.widgetWithText(MovieLogButton, '확인'));
      await tester.pumpAndSettle();
      expect(app.ratingApi.createCalls, hasLength(1));
      expect(app.ratingApi.recordCalls, isEmpty);
    });

    testWidgets('네트워크 실패는 Dialog 유지 + 입력 그대로', (tester) async {
      final app = await pumpApp(tester, location: AppRoutes.movieDetailOf(6));
      app.ratingApi.writeError = fakeHttpError('/v8/movie-records');

      await tester.tap(find.text('평점 남기기'));
      await tester.pumpAndSettle();
      await _tapStar(tester, 3);
      await tester.enterText(find.byType(TextField), '남길 코멘트');
      await tester.tap(find.byKey(const ValueKey('add-to-favorite')));
      await tester.tap(find.widgetWithText(MovieLogButton, '확인'));
      await tester.pumpAndSettle();

      expect(find.text('네트워크 연결을 확인하고 다시 시도해 주세요.'), findsOneWidget);
      expect(find.text('남길 코멘트'), findsOneWidget);
      expect(find.text('평점을 남겨주세요'), findsOneWidget);
    });
  });

  group('영화 검색', () {
    testWidgets('빈 검색어는 안 보냄 → 제출하면 결과 → 카드 누르면 상세', (tester) async {
      final movies = FakeTmdbMovieService();
      await pumpApp(
        tester,
        location: AppRoutes.movieSearch,
        movieService: movies,
      );
      expect(find.byType(MovieSearchScreen), findsOneWidget);
      expect(find.text('검색어를 입력해 주세요.'), findsOneWidget);

      await tester.tap(find.text('검색'));
      await tester.pump();
      expect(movies.searchCalls, isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey('search-field')),
        '영화 3',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(movies.searchCalls.single, (page: 1, query: '영화 3'));
      expect(find.widgetWithText(MovieSummaryCard, '영화 3'), findsOneWidget);

      await tester.tap(find.widgetWithText(MovieSummaryCard, '영화 3'));
      await tester.pumpAndSettle();
      expect(find.byType(MovieDetailScreen), findsOneWidget);
      expect(find.text('영화 3 줄거리'), findsOneWidget);
    });

    testWidgets('결과 없음 / 오류 + 다시 시도', (tester) async {
      final movies = FakeTmdbMovieService();
      await pumpApp(
        tester,
        location: AppRoutes.movieSearch,
        movieService: movies,
      );
      final field = find.byKey(const ValueKey('search-field'));

      await tester.enterText(field, '없는영화');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('검색 결과가 없습니다.'), findsOneWidget);

      movies.failSearch = true;
      await tester.enterText(field, '영화');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('검색 결과를 불러오지 못했습니다.'), findsOneWidget);

      movies.failSearch = false;
      await tester.tap(find.widgetWithText(MovieLogButton, '다시 시도'));
      await tester.pumpAndSettle();
      expect(find.byType(MovieSummaryCard), findsWidgets);
      expect(movies.searchCalls.last.query, '영화');
    });

    testWidgets('Challenge debounce: 입력 멈추고 500ms 뒤 마지막 검색어만 요청', (
      tester,
    ) async {
      final movies = FakeTmdbMovieService();
      await pumpApp(
        tester,
        location: AppRoutes.movieSearch,
        movieService: movies,
      );
      final field = find.byKey(const ValueKey('search-field'));

      await tester.enterText(field, '영');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(field, '영화');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(field, '영화 1');
      await tester.pump(const Duration(milliseconds: 499));
      expect(movies.searchCalls, isEmpty);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(movies.searchCalls.map((c) => c.query), ['영화 1']);

      // 공백만 입력하면 안 보냄
      await tester.enterText(field, '   ');
      await tester.pump(const Duration(milliseconds: 600));
      expect(movies.searchCalls, hasLength(1));
    });
  });
}
