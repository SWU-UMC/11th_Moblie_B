// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/main.dart';
import 'package:movielog/screens/profile_screen.dart';
import 'package:movielog/screens/signup_screen.dart';
import 'package:movielog/theme/app_theme.dart';

void main() {
  testWidgets('StartScreen shows title and CTA button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const StartScreen()),
    );

    expect(find.text('영화의 순간을\n기록하세요'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '시작하기'), findsOneWidget);
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
    await tester.enterText(find.byType(TextFormField).at(1), 'movie@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'password123');
    await tester.tap(find.text('필수 약관에 동의합니다'));
    await tester.pump();

    expect(submitButton().onPressed, isNotNull);
  });

  testWidgets('SignupScreen back button has an accessible tooltip', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const SignupScreen()),
    );

    expect(find.byTooltip('Back'), findsOneWidget);
  });

  testWidgets('ProfileScreen scrolls on a short screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const ProfileScreen()),
    );
    expect(tester.takeException(), isNull);

    final editButton = find.widgetWithText(ElevatedButton, '프로필 수정');
    await tester.scrollUntilVisible(editButton, 50);
    expect(editButton, findsOneWidget);
    // 수정 기능이 없으므로 버튼은 비활성화 상태입니다.
    expect(tester.widget<ElevatedButton>(editButton).onPressed, isNull);
  });
}
