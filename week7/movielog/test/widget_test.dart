import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/screens/profile_screen.dart';
import 'package:movielog/screens/start_screen.dart';
import 'package:movielog/theme/app_theme.dart';

Widget _wrap(Widget screen) => MaterialApp(theme: AppTheme.light, home: screen);

void main() {
  testWidgets('시작 화면에 문구와 시작하기 버튼이 보인다', (tester) async {
    await tester.pumpWidget(_wrap(const StartScreen()));

    expect(find.text('영화의 순간을\n기록하세요'), findsOneWidget);
    expect(find.text('시작하기'), findsOneWidget);
  });

  testWidgets('프로필 화면에 헤더, 통계, 장르, 수정 버튼이 보인다', (tester) async {
    await tester.pumpWidget(_wrap(const ProfileScreen()));

    expect(find.text('내 프로필'), findsOneWidget);
    expect(find.text('무비러버'), findsOneWidget);
    for (final label in ['본 영화', '평점', '즐겨찾기']) {
      expect(find.text(label), findsOneWidget);
    }
    for (final genre in ['드라마', 'SF', '애니메이션']) {
      expect(find.widgetWithText(Chip, genre), findsOneWidget);
    }
    expect(find.text('프로필 수정'), findsOneWidget);
  });

  testWidgets('작은 휴대폰 화면(360x640)에서도 Overflow가 없다', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const StartScreen()));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(_wrap(const ProfileScreen()));
    expect(tester.takeException(), isNull);
  });
}
