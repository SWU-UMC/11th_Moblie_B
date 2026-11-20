import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/data/movie_preferences.dart';
import 'package:movielog/router/app_routes.dart';
import 'package:movielog/screens/edit_profile_screen.dart';
import 'package:movielog/screens/splash_screen.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/widgets/movielog_button.dart';
import 'package:movielog/widgets/profile/discard_changes_dialog.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/app_harness.dart';
import 'support/fake_movie_log_services.dart';

Finder _field(String hint) => find.widgetWithText(TextFormField, hint);

Finder _emailField() => find.descendant(
  of: find.byKey(const Key('login-email')),
  matching: find.byType(TextFormField),
);

MovieLogButton _button(WidgetTester tester, String label) =>
    tester.widget(find.widgetWithText(MovieLogButton, label));

Future<void> _login(
  WidgetTester tester, {
  String email = 'movie@example.com',
  String password = 'Password1!',
}) async {
  await tester.enterText(find.byKey(const Key('login-email')), email);
  await tester.enterText(find.byKey(const Key('login-password')), password);
  await tester.tap(find.widgetWithText(MovieLogButton, '로그인'));
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('Splash·세션 복원', () {
    testWidgets('토큰 없으면 Splash → 로그인 화면 (홈 안 거침)', (tester) async {
      final app = await pumpApp(tester, signedIn: false);
      expect(app.location, AppRoutes.login);
      expect(find.text('MovieLog에 로그인'), findsOneWidget);
    });

    testWidgets('저장된 토큰은 GET me 성공한 뒤에만 홈', (tester) async {
      final memberApi = FakeMemberApiService()..fetchGate = Completer();
      final app = await pumpApp(tester, memberApi: memberApi, settle: false);
      await tester.pump();
      await tester.pump();
      // 확인 중엔 Splash (로그인·홈 안 보임)
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('MovieLog에 로그인'), findsNothing);

      memberApi.fetchGate!.complete();
      await tester.pumpAndSettle();
      expect(app.location, AppRoutes.home);
      expect(memberApi.fetchCalls, 1); // MainScreen이 다시 안 부름
    });

    testWidgets('네트워크 실패면 토큰 유지 + 재시도 화면, 다시 시도하면 홈', (tester) async {
      final memberApi = FakeMemberApiService()
        ..fetchError = fakeHttpError('/v7/members/me');
      final app = await pumpApp(tester, memberApi: memberApi);
      expect(app.location, AppRoutes.start);
      expect(find.text('로그인 상태를 확인하지 못했어요.'), findsOneWidget);
      expect(app.tokenStorage.token, 'saved-token');

      memberApi.fetchError = null;
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(app.location, AppRoutes.home);
    });

    testWidgets('만료 토큰이면 로그인 화면 + 만료 Snackbar 한 번', (tester) async {
      final memberApi = FakeMemberApiService()
        ..fetchError = fakeExpiredError('/v7/members/me');
      final app = await pumpApp(tester, memberApi: memberApi);
      expect(app.location, AppRoutes.login);
      expect(find.text('로그인이 만료됐어요. 다시 로그인해 주세요.'), findsOneWidget);
      expect(app.auth.sessionExpired, isFalse); // 띄운 뒤 consume
      expect(app.tokenStorage.token, isNull);
    });
  });

  group('로그인 화면', () {
    testWidgets('성공하면 Router가 홈으로 보내고 MainScreen이 내 정보 한 번 불러옴', (
      tester,
    ) async {
      final app = await pumpApp(tester, signedIn: false);
      await _login(tester);
      await tester.pumpAndSettle();

      expect(app.location, AppRoutes.home);
      expect(app.tokenStorage.token, 'token-1');
      expect(app.memberApi.fetchCalls, 1);
      expect(app.auth.member?.nickname, '무비러버');
      // 로그인 성공은 만료 Snackbar 아님
      expect(find.text('로그인이 만료됐어요. 다시 로그인해 주세요.'), findsNothing);
    });

    testWidgets('요청 중엔 버튼 로딩, 입력 막힘', (tester) async {
      final authApi = FakeAuthApiService()..gate = Completer();
      final app = await pumpApp(tester, signedIn: false, authApi: authApi);
      await _login(tester);
      await tester.pump();

      expect(app.auth.status, AuthStatus.authenticating);
      expect(_button(tester, '로그인').isLoading, isTrue);
      expect(tester.widget<TextFormField>(_emailField()).enabled, isFalse);
      authApi.gate!.complete();
      await tester.pumpAndSettle();
      expect(app.location, AppRoutes.home);
    });

    testWidgets('비밀번호 틀림: Form 문구, 만료 Snackbar 없음, 입력 유지', (tester) async {
      final app = await pumpApp(tester, signedIn: false);
      await _login(tester, password: 'Wrong1!');
      await tester.pumpAndSettle();

      expect(app.location, AppRoutes.login);
      expect(find.text('이메일 또는 비밀번호를 확인해 주세요.'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(
        tester.widget<TextFormField>(_emailField()).controller!.text,
        'movie@example.com',
      );
    });

    testWidgets('빈 칸이면 요청 안 함', (tester) async {
      final app = await pumpApp(tester, signedIn: false);
      await tester.tap(find.widgetWithText(MovieLogButton, '로그인'));
      await tester.pumpAndSettle();
      expect(find.text('이메일을 입력해 주세요.'), findsOneWidget);
      expect(app.authApi.calls, isEmpty);
    });

    testWidgets('Challenge 이메일 저장: 체크하면 이메일만 저장, 다음에 채워짐', (tester) async {
      final app = await pumpApp(tester, signedIn: false);
      await tester.tap(find.text('이메일 저장'));
      await tester.pump();
      await _login(tester);
      await tester.pumpAndSettle();

      final preferences = MoviePreferences();
      expect(await preferences.readSavedEmail(), 'movie@example.com');

      await app.auth.logout();
      await tester.pumpAndSettle();
      expect(app.location, AppRoutes.login);
      // 로그인 화면 새로 열리면서 저장한 이메일 채움
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(_emailField()).controller!.text,
        'movie@example.com',
      );
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isTrue);
    });
  });

  group('마이페이지·로그아웃', () {
    testWidgets('GET me 닉네임·이메일·가입일 표시, 로그아웃하면 /login (만료 Snackbar 없음)', (
      tester,
    ) async {
      final app = await pumpApp(tester, location: AppRoutes.my);
      expect(find.text('무비러버'), findsOneWidget);
      expect(find.text('movie@example.com'), findsOneWidget);
      expect(find.text('2026.10.10 가입'), findsOneWidget);

      await tester.tap(find.text('로그아웃'));
      await tester.pumpAndSettle();
      expect(app.location, AppRoutes.login);
      expect(app.tokenStorage.token, isNull);
      expect(find.text('로그인이 만료됐어요. 다시 로그인해 주세요.'), findsNothing);

      // 로그아웃 후 보호 화면 직접 가도 막힘
      app.router.go(AppRoutes.myRatings);
      await tester.pumpAndSettle();
      expect(app.location, AppRoutes.login);
    });

    testWidgets('Challenge: 내 정보 로딩 중 전체 인디케이터, 실패하면 재시도', (tester) async {
      final memberApi = FakeMemberApiService();
      final app = await pumpApp(tester, signedIn: false, memberApi: memberApi);
      memberApi.fetchError = fakeHttpError('/v7/members/me');
      await _login(tester);
      await tester.pumpAndSettle();
      app.router.go(AppRoutes.my);
      await tester.pumpAndSettle();

      expect(find.text('내 정보를 불러오지 못했어요.'), findsOneWidget);
      expect(app.auth.status, AuthStatus.signedIn); // 로그아웃 안 함

      memberApi
        ..fetchError = null
        ..fetchGate = Completer();
      await tester.tap(find.text('다시 시도'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      memberApi.fetchGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('무비러버'), findsOneWidget);
    });
  });

  group('프로필 수정', () {
    Future<TestApp> openEdit(
      WidgetTester tester, {
      FakeMemberApiService? memberApi,
    }) async {
      final app = await pumpApp(
        tester,
        location: AppRoutes.my,
        memberApi: memberApi,
      );
      await tester.tap(find.text('프로필 수정'));
      await tester.pumpAndSettle();
      expect(find.byType(EditProfileScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing); // root Navigator
      return app;
    }

    testWidgets('이메일 읽기 전용, 닉네임 저장 성공 → Snackbar + 마이페이지에 바로 반영', (
      tester,
    ) async {
      final app = await openEdit(tester);
      final email = tester.widget<TextField>(
        find.descendant(
          of: find.widgetWithText(TextFormField, 'movie@example.com'),
          matching: find.byType(TextField),
        ),
      );
      expect(email.readOnly, isTrue);

      await tester.enterText(_field('무비러버'), '새닉네임');
      await tester.tap(find.widgetWithText(MovieLogButton, '저장'));
      await tester.pumpAndSettle();

      expect(app.memberApi.updateCalls, ['새닉네임']);
      expect(find.text('프로필을 수정했어요.'), findsOneWidget);
      expect(find.byType(EditProfileScreen), findsNothing);
      expect(find.text('새닉네임'), findsOneWidget);
    });

    testWidgets('저장 중: 로딩·입력 막힘·뒤로가기 막힘', (tester) async {
      final memberApi = FakeMemberApiService()..updateGate = Completer();
      await openEdit(tester, memberApi: memberApi);
      await tester.enterText(_field('무비러버'), '새닉네임');
      await tester.tap(find.widgetWithText(MovieLogButton, '저장'));
      await tester.pump();

      expect(_button(tester, '저장').isLoading, isTrue);
      expect(
        tester
            .widget<PopScope>(find.byWidgetPredicate((w) => w is PopScope).last)
            .canPop,
        isFalse,
      );
      memberApi.updateGate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('중복(MEMBER409_1): 입력칸 오류, 입력값 유지, 화면 그대로', (tester) async {
      final memberApi = FakeMemberApiService(takenNicknames: {'중복닉'});
      await openEdit(tester, memberApi: memberApi);
      await tester.enterText(_field('무비러버'), '중복닉');
      await tester.tap(find.widgetWithText(MovieLogButton, '저장'));
      await tester.pumpAndSettle();

      expect(find.text('이미 사용 중인 닉네임이에요.'), findsOneWidget);
      expect(find.text('중복닉'), findsOneWidget);
      expect(find.byType(EditProfileScreen), findsOneWidget);
    });

    testWidgets('네트워크 실패: Snackbar, 로그아웃 안 함', (tester) async {
      final memberApi = FakeMemberApiService()
        ..updateError = fakeHttpError('/v7/members/me');
      final app = await openEdit(tester, memberApi: memberApi);
      await tester.enterText(_field('무비러버'), '새닉네임');
      await tester.tap(find.widgetWithText(MovieLogButton, '저장'));
      await tester.pumpAndSettle();

      expect(find.text('네트워크 상태를 확인하고 다시 시도해 주세요.'), findsOneWidget);
      expect(app.auth.status, AuthStatus.signedIn);
    });

    testWidgets('Challenge: 바꾼 내용 있으면 뒤로가기 확인 Dialog', (tester) async {
      final app = await openEdit(tester);

      // 안 바꿨으면 바로 나감
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(EditProfileScreen), findsNothing);

      await tester.tap(find.text('프로필 수정'));
      await tester.pumpAndSettle();
      await tester.enterText(_field('무비러버'), '바꾸는중');
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(DiscardChangesDialog), findsOneWidget);

      await tester.tap(find.text('계속 수정'));
      await tester.pumpAndSettle();
      expect(find.byType(EditProfileScreen), findsOneWidget);
      expect(find.text('바꾸는중'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('나가기'));
      await tester.pumpAndSettle();
      expect(find.byType(EditProfileScreen), findsNothing);
      expect(app.memberApi.updateCalls, isEmpty);
    });
  });

  group('Figma 크기 (390 x 844)', () {
    testWidgets('로그인: 입력칸 342x48, 버튼 342x44, 버튼 위치 고정 (실패 문구 있어도)', (
      tester,
    ) async {
      await pumpApp(tester, signedIn: false, size: const Size(390, 844));
      final field = find.byKey(const Key('login-email'));
      expect(tester.getSize(field), const Size(342, 48));
      final button = find.widgetWithText(MovieLogButton, '로그인');
      expect(tester.getSize(button), const Size(342, 44));
      final top = tester.getTopLeft(button).dy;

      await _login(tester, password: 'Wrong1!');
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(button).dy, top); // 문구 생겨도 안 밀림
      // 이메일 저장 체크 22
      expect(
        tester.getSize(
          find
              .ancestor(
                of: find.byType(Checkbox),
                matching: find.byType(SizedBox),
              )
              .first,
        ),
        const Size(22, 22),
      );
    });

    testWidgets('마이페이지: 사진 126, 수정 128x40, 통계 114x86, 평점 행 358x64', (
      tester,
    ) async {
      await pumpApp(tester, location: AppRoutes.my, size: const Size(390, 844));
      expect(tester.getSize(find.byType(Image).first), const Size(126, 126));
      expect(
        tester.getSize(find.widgetWithText(OutlinedButton, '프로필 수정')),
        const Size(128, 40),
      );
      expect(
        tester.getSize(
          find
              .ancestor(of: find.text('본 영화'), matching: find.byType(Container))
              .first,
        ),
        const Size(114, 86),
      );
      expect(
        tester.getSize(
          find
              .ancestor(
                of: find.text('내가 등록한 평점'),
                matching: find.byType(Material),
              )
              .first,
        ),
        const Size(358, 64),
      );
      expect(find.text('2026.10.10 가입'), findsOneWidget);
      // 장르 칩은 글자만큼 (드라마 69)
      final chip = find
          .ancestor(of: find.text('드라마'), matching: find.byType(Container))
          .first;
      expect(tester.getSize(chip).width, lessThan(80));
      expect(tester.getSize(chip).height, 33);
    });

    testWidgets('프로필 수정: 입력칸 342x48, 저장 342x44, 카운터 "4 / 12"', (tester) async {
      await pumpApp(tester, location: AppRoutes.my, size: const Size(390, 844));
      await tester.tap(find.text('프로필 수정'));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(TextFormField).first),
        const Size(342, 48),
      );
      expect(
        tester.getSize(find.widgetWithText(MovieLogButton, '저장')),
        const Size(342, 44),
      );
      expect(find.text('4 / 12'), findsOneWidget);
    });
  });
}
