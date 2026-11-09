import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:movielog/data/movie_preferences.dart';
import 'package:movielog/main.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/router/app_routes.dart';
import 'package:movielog/screens/my_ratings_screen.dart';
import 'package:movielog/widgets/movielog_button.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_movie_log_services.dart';
import 'support/fake_tmdb_movie_service.dart';

Future<GoRouter> _pumpApp(
  WidgetTester tester,
  String location, {
  FakeRatingApiService? ratingService,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = AppRouter.createRouter(
    initialLocation: location,
    preferences: MoviePreferences(),
  );
  await tester.pumpWidget(
    MovieLogApp(
      router: router,
      movieService: FakeTmdbMovieService(),
      memberCheckService: FakeMemberCheckService(),
      ratingApiService: ratingService ?? FakeRatingApiService(),
    ),
  );
  if (settle) await tester.pumpAndSettle();
  return router;
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('마이페이지 → 내가 등록한 평점: 하단 NavigationBar 없이 열리고 뒤로 가면 돌아온다', (
    tester,
  ) async {
    final router = await _pumpApp(tester, AppRoutes.my);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text('내가 등록한 평점'));
    await tester.pumpAndSettle();

    expect(find.byType(MyRatingsScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(router.canPop(), isTrue);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(MyRatingsScreen), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('Success: 평점 카드에 TMDB 제목·별점·후기·등록일을 보여주고 후기 null은 숨긴다', (
    tester,
  ) async {
    await _pumpApp(tester, AppRoutes.myRatings);

    expect(find.text('학습용 memberId 1의 공개 조회입니다.'), findsOneWidget);
    expect(find.byType(RatingCard), findsNWidgets(3));
    expect(find.text('영화 13'), findsOneWidget);
    expect(find.text('별점 3 / 5'), findsOneWidget);
    expect(find.text('다시 봐도 좋다'), findsOneWidget);
    expect(find.text('최고의 영화!'), findsOneWidget);
    expect(find.text('등록일 2026.09.06'), findsNWidgets(3));
  });

  testWidgets('TMDB에 없는 영화는 "영화 #id"와 포스터 정보 없음으로 보여준다', (tester) async {
    await _pumpApp(
      tester,
      AppRoutes.myRatings,
      ratingService: FakeRatingApiService(ratings: [fakeRating(1, 999)]),
    );

    expect(find.text('영화 #999'), findsOneWidget);
    expect(find.text('포스터 정보 없음'), findsOneWidget);
    expect(find.textContaining('일부 영화 정보를 가져오지 못해'), findsOneWidget);
  });

  testWidgets('Loading: 불러오는 동안 진행 표시', (tester) async {
    final ratings = FakeRatingApiService()..gate = Completer();
    await _pumpApp(
      tester,
      AppRoutes.myRatings,
      ratingService: ratings,
      settle: false,
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    ratings.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(RatingCard), findsNWidgets(3));
  });

  testWidgets('Empty: 평점이 없으면 Error가 아니라 안내 문구', (tester) async {
    await _pumpApp(
      tester,
      AppRoutes.myRatings,
      ratingService: FakeRatingApiService(ratings: []),
    );
    expect(find.text('아직 등록된 평점이 없어요.'), findsOneWidget);
    expect(find.text('다시 시도'), findsNothing);
  });

  testWidgets('Error: 없는 회원(404) 문구와 고정 너비 다시 시도 버튼, 재시도하면 성공', (tester) async {
    final ratings = FakeRatingApiService()..failStatus = 404;
    await _pumpApp(tester, AppRoutes.myRatings, ratingService: ratings);

    expect(find.text('존재하지 않는 회원입니다.'), findsOneWidget);
    final retry = find.widgetWithText(MovieLogButton, '다시 시도');
    expect(tester.getSize(retry).width, 120);

    ratings.failStatus = null;
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(find.byType(RatingCard), findsNWidgets(3));
  });
}
