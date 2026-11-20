import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/screens/splash_screen.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/app_harness.dart';

Widget _wrap(Widget screen) => MaterialApp(theme: AppTheme.light, home: screen);

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('Splash: 확인 중엔 인디케이터, 실패하면 문구와 다시 시도', (tester) async {
    await tester.pumpWidget(_wrap(const SplashScreen()));
    expect(find.text('FLUTTER 8주차'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('다시 시도'), findsNothing);

    var retried = 0;
    await tester.pumpWidget(
      _wrap(
        SplashScreen(message: '로그인 상태를 확인하지 못했어요.', onRetry: () => retried++),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('로그인 상태를 확인하지 못했어요.'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    expect(retried, 1);
  });

  testWidgets('프로필 화면에 헤더, 통계, 장르, 수정 버튼이 보인다', (tester) async {
    await pumpApp(tester, location: '/my');

    expect(find.text('내 프로필'), findsOneWidget);
    expect(find.text('무비러버'), findsOneWidget);
    for (final label in ['본 영화', '평점', '즐겨찾기']) {
      expect(find.text(label), findsOneWidget);
    }
    for (final genre in ['드라마', 'SF', '애니메이션']) {
      expect(find.text(genre), findsOneWidget);
    }
    expect(find.text('프로필 수정'), findsOneWidget);
  });

  testWidgets('작은 휴대폰 화면(360x640)에서도 Overflow가 없다', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const SplashScreen()));
    expect(tester.takeException(), isNull);

    await pumpApp(tester, location: '/my', size: null);
    expect(tester.takeException(), isNull);
  });
}
