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
import 'package:movielog/theme/app_theme.dart';

void main() {
  testWidgets('StartScreen shows title and CTA button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MovieLogApp());

    expect(find.text('영화의 순간을\n기록하세요'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '시작하기'), findsOneWidget);
  });

  testWidgets('StartScreen scrolls to CTA on a short screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MovieLogApp());
    expect(tester.takeException(), isNull);

    final startButton = find.widgetWithText(ElevatedButton, '시작하기');
    await tester.scrollUntilVisible(startButton, 50);
    expect(startButton, findsOneWidget);
  });

  testWidgets('StartScreen keeps CTA at the bottom on a tall screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MovieLogApp());

    // 화면 하단 여백(32) 바로 위에 버튼이 위치해야 합니다.
    final buttonRect = tester.getRect(
      find.widgetWithText(ElevatedButton, '시작하기'),
    );
    expect(buttonRect.bottom, closeTo(915 - 32, 1));
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
  });
}
