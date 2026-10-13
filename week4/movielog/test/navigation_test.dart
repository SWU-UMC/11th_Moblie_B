import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:movielog/main.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/router/app_routes.dart';
import 'package:movielog/services/fake_movie_service.dart';
import 'package:movielog/widgets/movie/genre_chip_bar.dart';
import 'package:movielog/widgets/movie/movie_poster_card.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// 4주차: 영화 목록은 Mock Service를 지연 없이, 저장소는 메모리로 사용합니다.
GoRouter _createRouter(String location) => AppRouter.createRouter(
  initialLocation: location,
  movieService: const FakeMovieService(delay: Duration.zero),
);

/// 휴대폰 크기 화면에서 [initialLocation]부터 시작하는 앱을 띄웁니다.
Future<GoRouter> _pumpApp(WidgetTester tester, String initialLocation) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = _createRouter(initialLocation);
  await tester.pumpWidget(MovieLogApp(router: router));
  await tester.pumpAndSettle();
  return router;
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

Finder _navDestination(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

Finder _posterTitled(String title) =>
    find.widgetWithText(MoviePosterCard, title);

Future<void> _tapLastStar(WidgetTester tester) async {
  final lastStar = find.byIcon(Icons.star_rounded).last;
  await tester.tapAt(tester.getTopRight(lastStar) + const Offset(-2, 10));
  await tester.pump();
}

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
    expect(find.byIcon(Icons.arrow_back), findsNothing);

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

  testWidgets('NavigationBar로 홈·영화·마이 탭을 전환한다', (tester) async {
    final router = await _pumpApp(tester, AppRoutes.home);

    await tester.tap(_navDestination('영화'));
    await tester.pumpAndSettle();
    expect(_location(router), AppRoutes.movies);
    expect(find.byType(GridView), findsOneWidget);

    await tester.tap(_navDestination('마이'));
    await tester.pumpAndSettle();
    expect(_location(router), AppRoutes.my);
    expect(find.text('내 프로필'), findsOneWidget);

    await tester.tap(_navDestination('홈'));
    await tester.pumpAndSettle();
    expect(_location(router), AppRoutes.home);
  });

  testWidgets('홈 추천 카드에서 상세로 push하고 뒤로 가기로 돌아온다', (tester) async {
    final router = await _pumpApp(tester, AppRoutes.home);

    await tester.tap(find.text('상세보기'));
    await tester.pumpAndSettle();
    // push는 홈 위에 상세를 쌓으므로 뒤로 갈 수 있습니다.
    expect(router.canPop(), isTrue);
    expect(find.text('Cinema Archive'), findsOneWidget);
    expect(find.text('별빛 아래 우리'), findsOneWidget);

    await tester.tap(find.byTooltip('뒤로 가기'));
    await tester.pumpAndSettle();
    expect(router.canPop(), isFalse);
    expect(_location(router), AppRoutes.home);
    expect(find.text('오늘은 어떤\n영화를 볼까요?'), findsOneWidget);
  });

  testWidgets('목록 카드를 누르면 Path Parameter의 ID로 같은 영화를 보여준다', (tester) async {
    final router = await _pumpApp(tester, AppRoutes.movies);

    await tester.tap(_posterTitled('우주의 끝에서'));
    await tester.pumpAndSettle();
    expect(router.canPop(), isTrue);
    expect(find.text('Cinema Archive'), findsOneWidget);
    expect(find.text('우주의 끝에서'), findsOneWidget);
    expect(find.text('2024 • SF • 138분'), findsOneWidget);

    // Android 시스템 뒤로 가기
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.canPop(), isFalse);
    expect(find.byType(GridView), findsOneWidget);
  });

  testWidgets('작은 휴대폰 화면(360x640)에서 모든 탭과 상세에 Overflow가 없다', (tester) async {
    for (final location in [
      AppRoutes.home,
      AppRoutes.movies,
      AppRoutes.my,
      AppRoutes.movieDetailOf(1),
    ]) {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MovieLogApp(router: _createRouter(location)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: location);
    }
  });

  testWidgets('없는 영화 ID로 들어오면 안내 문구를 보여준다', (tester) async {
    await _pumpApp(tester, '/movies/999');
    expect(find.text('영화를 찾을 수 없어요'), findsOneWidget);
  });

  testWidgets('장르 Chip을 누르면 Query Parameter와 목록이 함께 바뀐다', (tester) async {
    final router = await _pumpApp(tester, AppRoutes.movies);

    await tester.tap(find.widgetWithText(ChoiceChip, 'SF'));
    await tester.pumpAndSettle();

    expect(_location(router), AppRoutes.moviesWithGenres({'SF'}));
    expect(find.byType(MoviePosterCard), findsNWidgets(2));
    expect(_posterTitled('우주의 끝에서'), findsOneWidget);
    expect(_posterTitled('어비스 워커'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, '전체'));
    await tester.pumpAndSettle();
    expect(_location(router), AppRoutes.movies);
  });

  testWidgets('필터 BottomSheet는 확인을 눌러야 여러 장르를 적용한다', (tester) async {
    final router = await _pumpApp(tester, AppRoutes.movies);

    await tester.tap(find.byTooltip('장르 필터'));
    await tester.pumpAndSettle();
    expect(find.text('장르 필터'), findsOneWidget);

    for (final genre in ['SF', '스릴러']) {
      final tile = find.widgetWithText(CheckboxListTile, genre);
      // 장르 목록은 Sheet 안에서 스크롤되므로 보이게 한 뒤 누릅니다.
      await tester.scrollUntilVisible(
        tile,
        50,
        scrollable: find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(tile);
      await tester.pump();
    }
    // 확인 전에는 목록 필터가 바뀌지 않습니다.
    expect(_location(router), AppRoutes.movies);

    await tester.tap(find.widgetWithText(ElevatedButton, '확인'));
    await tester.pumpAndSettle();

    expect(_location(router), AppRoutes.moviesWithGenres({'SF', '스릴러'}));
    expect(find.byType(MoviePosterCard), findsNWidgets(3));
    expect(_posterTitled('밤의 그림자'), findsOneWidget);
  });

  testWidgets('평점 Dialog: 별점을 골라야 확인이 켜지고, 다시 선택하면 초기화된다', (tester) async {
    await _pumpApp(tester, AppRoutes.movieDetailOf(1));

    await tester.tap(find.text('평점 남기기'));
    await tester.pumpAndSettle();
    expect(find.text('영화는 어떠셨나요?'), findsOneWidget);

    ElevatedButton confirm() =>
        tester.widget(find.widgetWithText(ElevatedButton, '확인'));
    expect(confirm().onPressed, isNull);

    await _tapLastStar(tester);
    expect(find.text('5.0점'), findsOneWidget);
    expect(confirm().onPressed, isNotNull);

    await tester.tap(find.text('다시 선택'));
    await tester.pump();
    expect(find.text('별을 눌러 평점을 선택해주세요'), findsOneWidget);
    expect(confirm().onPressed, isNull);

    await _tapLastStar(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, '확인'));
    await tester.pumpAndSettle();

    expect(find.text('평점 5.0점을 남겼어요.'), findsOneWidget);
    expect(find.text('내 평점 5.0'), findsOneWidget);
  });

  testWidgets('즐겨찾기를 누르면 Snackbar와 아이콘이 바뀐다', (tester) async {
    await _pumpApp(tester, AppRoutes.movieDetailOf(1));

    await tester.tap(find.text('즐겨찾기'));
    await tester.pumpAndSettle();
    expect(find.text('별빛 아래 우리을(를) 즐겨찾기에 추가했어요.'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);

    await tester.tap(find.text('즐겨찾기됨'));
    await tester.pumpAndSettle();
    expect(find.text('별빛 아래 우리을(를) 즐겨찾기에서 삭제했어요.'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
  });

  testWidgets('영화 탭에서 고른 필터는 다른 탭에 다녀와도 유지된다', (tester) async {
    final router = await _pumpApp(tester, AppRoutes.movies);

    // 가로 Chip 목록을 스크롤해 '스릴러'를 보이게 한 뒤 누릅니다.
    final chip = find.widgetWithText(ChoiceChip, '스릴러');
    await tester.scrollUntilVisible(
      chip,
      80,
      scrollable: find.descendant(
        of: find.byType(GenreChipBar),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(chip);
    await tester.pumpAndSettle();
    await tester.tap(_navDestination('홈'));
    await tester.pumpAndSettle();
    await tester.tap(_navDestination('영화'));
    await tester.pumpAndSettle();

    // StatefulShellRoute: 영화 탭의 필터 위치가 그대로 남아 있습니다.
    expect(_location(router), AppRoutes.moviesWithGenres({'스릴러'}));
  });
}
