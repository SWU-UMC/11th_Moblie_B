import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:movielog/main.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/screens/signup_screen.dart';
import 'package:movielog/screens/start_screen.dart';
import 'package:movielog/theme/app_theme.dart';

void main() {
  Future<GoRouter> pumpApp(
    WidgetTester tester, {
    String initialLocation = '/',
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final router = createAppRouter(initialLocation: initialLocation);
    await tester.pumpWidget(MovieLogApp(router: router));
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('StartScreen shows title and CTA button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const StartScreen()),
    );

    expect(find.text('영화의 순간을\n기록하세요'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '시작하기'), findsOneWidget);
  });

  testWidgets('Start -> Signup -> Home, and back is blocked', (
    WidgetTester tester,
  ) async {
    final router = await pumpApp(tester);

    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();
    expect(find.text('회원가입'), findsOneWidget);
    expect(router.canPop(), isFalse);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '무비러버');
    await tester.enterText(fields.at(1), 'movie@example.com');
    await tester.enterText(fields.at(2), 'password123');
    await tester.tap(find.text('필수 약관에 동의합니다'));
    await tester.pump();
    await tester.tap(find.text('가입하기'));
    await tester.pumpAndSettle();

    expect(find.text('오늘은 어떤\n영화를 볼까요?'), findsOneWidget);
    expect(router.canPop(), isFalse);

    // 시스템 뒤로 가기를 눌러도 홈에 그대로 머뭅니다.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('오늘은 어떤\n영화를 볼까요?'), findsOneWidget);
  });

  testWidgets('Home featured card opens detail and returns back', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, initialLocation: '/home');

    await tester.tap(find.text('상세보기'));
    await tester.pumpAndSettle();

    expect(find.text('Cinema Archive'), findsOneWidget);
    expect(find.text('별빛 아래 우리'), findsOneWidget);
    expect(find.text('2024 • 로맨스/드라마 • 124분'), findsOneWidget);

    // AppBar의 첫 번째 IconButton이 뒤로가기 버튼입니다.
    await tester.tap(find.byType(IconButton).first);
    await tester.pumpAndSettle();

    expect(find.text('오늘은 어떤\n영화를 볼까요?'), findsOneWidget);
  });

  testWidgets('NavigationBar switches tabs and genre chip filters movies', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, initialLocation: '/home');

    await tester.tap(find.text('영화'));
    await tester.pumpAndSettle();
    expect(find.text('별빛 아래 우리'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'SF'));
    await tester.pumpAndSettle();
    expect(find.text('우주의 끝에서'), findsOneWidget);
    expect(find.text('별빛 아래 우리'), findsNothing);

    await tester.tap(find.text('마이'));
    await tester.pumpAndSettle();
    expect(find.text('내 프로필'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
  });

  testWidgets('Detail rating dialog and favorite snackbar', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, initialLocation: '/movies/under-the-starlight');

    await tester.tap(find.text('평점 남기기'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    FilledButton saveButton() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, '저장'));
    expect(saveButton().onPressed, isNull);

    final stars = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byIcon(Icons.star_rounded),
    );
    await tester.tap(stars.last);
    await tester.pumpAndSettle();
    expect(saveButton().onPressed, isNotNull);

    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining('점을 남겼어요.'), findsOneWidget);

    await tester.tap(find.text('즐겨찾기'));
    await tester.pumpAndSettle();
    expect(find.text('즐겨찾기에 추가했어요.'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);

    await tester.tap(find.text('즐겨찾기 해제'));
    await tester.pumpAndSettle();
    expect(find.text('즐겨찾기에서 삭제했어요.'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
  });

  testWidgets('Profile edit opens a bottom sheet', (WidgetTester tester) async {
    await pumpApp(tester, initialLocation: '/my');

    await tester.tap(find.text('프로필 수정'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '시네필');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('시네필'), findsOneWidget);
    expect(find.text('프로필을 수정했어요.'), findsOneWidget);
  });

  testWidgets('SignupScreen validates fields and toggles submit button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const SignupScreen()),
    );

    final submitButtonFinder = find.widgetWithText(ElevatedButton, '가입하기');
    ElevatedButton submitButton() =>
        tester.widget<ElevatedButton>(submitButtonFinder);

    expect(submitButton().onPressed, isNull);

    await tester.enterText(find.byType(TextFormField).at(0), 'a');
    await tester.pump();
    expect(find.text('닉네임은 2자 이상이어야 합니다.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), '무비러버');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'movie@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(2), 'password123');
    await tester.tap(find.text('필수 약관에 동의합니다'));
    await tester.pump();

    expect(submitButton().onPressed, isNotNull);
  });
}
