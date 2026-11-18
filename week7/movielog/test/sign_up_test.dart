import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/main.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/router/app_routes.dart';
import 'package:movielog/screens/sign_up_screen.dart';
import 'package:movielog/utils/sign_up_validators.dart';
import 'package:movielog/widgets/movielog_button.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_movie_log_services.dart';
import 'support/fake_tmdb_movie_service.dart';

/// 회원가입 화면부터 시작 (Fake Service)
Widget _app({FakeSignUpService? signUpService}) => MovieLogApp(
  router: AppRouter.createRouter(initialLocation: AppRoutes.register),
  movieService: FakeTmdbMovieService(),
  signUpService: signUpService ?? FakeSignUpService(),
  ratingApiService: FakeRatingApiService(),
);

Finder _field(String hint) => find.widgetWithText(TextFormField, hint);

/// 0: 닉네임, 1: 이메일
Finder _checkButton(int index) =>
    find.widgetWithText(MovieLogButton, '중복 확인').at(index);

MovieLogButton _checkButtonWidget(WidgetTester tester, int index) =>
    tester.widget(find.byType(MovieLogButton).at(index));

ElevatedButton _signUpButton(WidgetTester tester) =>
    tester.widget(find.widgetWithText(ElevatedButton, '가입하기'));

Future<void> _fillValidForm(WidgetTester tester) async {
  await tester.enterText(_field('닉네임을 입력해주세요'), '제로');
  await tester.enterText(_field('이메일 주소를 입력해주세요'), 'movie@example.com');
  await tester.enterText(_field('비밀번호를 입력해주세요'), 'Password1!');
  await tester.pump();
}

void main() {
  // 가입 성공하면 영화 목록으로 가서 필터 저장소 필요
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('SignUpValidators', () {
    test('닉네임은 비어 있거나 2자 미만이면 오류', () {
      expect(SignUpValidators.nickname(''), '닉네임을 입력해주세요.');
      expect(SignUpValidators.nickname(' a '), '닉네임은 2자 이상이어야 합니다.');
      expect(SignUpValidators.nickname('무비'), isNull);
    });

    test('이메일 형식 검사', () {
      expect(SignUpValidators.email(''), '이메일을 입력해주세요.');
      expect(SignUpValidators.email('test@'), '올바른 이메일 형식이 아닙니다.');
      expect(SignUpValidators.email('movie@example.com'), isNull);
    });

    test('비밀번호는 대·소문자·숫자·특수문자 포함 8자 이상 (v6 제약)', () {
      expect(SignUpValidators.password(''), '비밀번호를 입력해주세요.');
      for (final weak in [
        'Ab1!',
        'password123',
        'PASSWORD1!',
        'Password!!',
        'Password12',
      ]) {
        expect(
          SignUpValidators.password(weak),
          SignUpValidators.passwordRuleMessage,
          reason: weak,
        );
      }
      expect(SignUpValidators.password('Password1!'), isNull);
    });

    test('닉네임은 2~12자', () {
      expect(SignUpValidators.nickname('가나다라마바사아자차카타'), isNull); // 12자
      expect(SignUpValidators.nickname('가나다라마바사아자차카타파'), '닉네임은 12자 이하여야 합니다.');
    });
  });

  testWidgets('입력 전에는 가입하기·중복 확인 버튼이 비활성화되어 있다', (tester) async {
    await tester.pumpWidget(_app());

    expect(find.byType(SignUpScreen), findsOneWidget);
    expect(_signUpButton(tester).onPressed, isNull);
    expect(_checkButtonWidget(tester, 0).onPressed, isNull);
    expect(_checkButtonWidget(tester, 1).onPressed, isNull);
  });

  testWidgets('잘못 입력하면 한국어 오류 메시지가 보인다', (tester) async {
    // 360x640
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());

    await tester.enterText(_field('닉네임을 입력해주세요'), 'a');
    await tester.enterText(_field('이메일 주소를 입력해주세요'), 'test@');
    await tester.enterText(_field('비밀번호를 입력해주세요'), '123');
    await tester.pump();

    expect(find.text('닉네임은 2자 이상이어야 합니다.'), findsOneWidget);
    expect(find.text('올바른 이메일 형식이 아닙니다.'), findsOneWidget);
    expect(find.text(SignUpValidators.passwordRuleMessage), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsNWidgets(3));
    expect(_signUpButton(tester).onPressed, isNull);
  });

  testWidgets('중복 확인을 둘 다 통과하고 약관에 동의해야 가입할 수 있다', (tester) async {
    await tester.pumpWidget(_app());

    await _fillValidForm(tester);
    // 중복 확인 전이라 비밀번호만 체크 표시
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.text('중복 확인을 눌러 주세요.'), findsNWidgets(2));

    await tester.tap(find.text('필수 약관에 동의합니다'));
    await tester.pump();
    expect(_signUpButton(tester).onPressed, isNull);

    await tester.tap(_checkButton(0));
    await tester.tap(_checkButton(1));
    await tester.pumpAndSettle();
    expect(find.text('사용 가능한 닉네임입니다.'), findsOneWidget);
    expect(find.text('사용 가능한 이메일입니다.'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNWidgets(3));
    expect(_signUpButton(tester).onPressed, isNotNull);

    await tester.tap(find.text('가입하기'));
    await tester.pumpAndSettle();
    expect(find.text('제로님, 가입을 환영해요! (memberId 42)'), findsOneWidget);
  });

  testWidgets('통신 중에는 버튼이 비활성화되고 인디케이터만 보인다', (tester) async {
    final service = FakeSignUpService()..gate = Completer();
    await tester.pumpWidget(_app(signUpService: service));
    await _fillValidForm(tester);
    final idleWidth = tester.getSize(find.byType(MovieLogButton).first).width;

    await tester.tap(_checkButton(0));
    await tester.pump();

    // 로딩 중에도 버튼 너비 그대로
    expect(tester.getSize(find.byType(MovieLogButton).first).width, idleWidth);
    final checking = _checkButtonWidget(tester, 0);
    expect(checking.isLoading, isTrue);
    expect(
      find.descendant(
        of: find.byType(MovieLogButton).first,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<ElevatedButton>(
            find.descendant(
              of: find.byType(MovieLogButton).first,
              matching: find.byType(ElevatedButton),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('닉네임 사용 가능 여부를 확인 중입니다.'), findsOneWidget);

    service.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('사용 가능한 닉네임입니다.'), findsOneWidget);
  });

  testWidgets('중복이면 Form이 에러가 되고, 고치면 풀리고, 같은 값을 다시 쓰면 바로 에러', (tester) async {
    final service = FakeSignUpService();
    await tester.pumpWidget(_app(signUpService: service));
    await tester.enterText(_field('닉네임을 입력해주세요'), '무비러버');
    await tester.pump();

    await tester.tap(_checkButton(0));
    await tester.pumpAndSettle();
    expect(find.text('이미 사용 중인 닉네임입니다.'), findsOneWidget);
    expect(_checkButtonWidget(tester, 0).onPressed, isNull);

    await tester.enterText(_field('무비러버'), '무비러버2');
    await tester.pumpAndSettle(); // 에러 문구 사라지는 애니메이션 대기
    expect(find.text('이미 사용 중인 닉네임입니다.'), findsNothing);
    expect(_checkButtonWidget(tester, 0).onPressed, isNotNull);

    await tester.enterText(_field('무비러버2'), '무비러버');
    await tester.pumpAndSettle();
    expect(find.text('이미 사용 중인 닉네임입니다.'), findsOneWidget);
    expect(_checkButtonWidget(tester, 0).onPressed, isNull);
    expect(service.nicknameCalls, ['무비러버']); // 다시 요청 안 함
  });

  testWidgets('통신 실패는 중복과 다른 문구로 보인다', (tester) async {
    final service = FakeSignUpService()..fail = true;
    await tester.pumpWidget(_app(signUpService: service));
    await _fillValidForm(tester);

    await tester.tap(_checkButton(1));
    await tester.pumpAndSettle();
    expect(find.text('중복 확인에 실패했습니다. 다시 시도해 주세요.'), findsOneWidget);
    expect(find.text('이미 사용 중인 이메일입니다.'), findsNothing);
  });

  testWidgets('MovieLogButton 너비: 중복 확인은 글자만큼, 가입하기는 Form 전체', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());

    final formWidth = tester.getSize(find.byType(Form)).width;
    final checkWidth = tester.getSize(_checkButton(0)).width;
    final submitWidth = tester
        .getSize(find.widgetWithText(MovieLogButton, '가입하기'))
        .width;

    expect(checkWidth, lessThan(formWidth / 2));
    expect(submitWidth, formWidth);
  });

  testWidgets('비밀번호 표시·숨김 버튼으로 obscureText가 바뀐다', (tester) async {
    await tester.pumpWidget(_app());

    EditableText passwordText() => tester.widget<EditableText>(
      find.descendant(
        of: _field('비밀번호를 입력해주세요'),
        matching: find.byType(EditableText),
      ),
    );

    expect(passwordText().obscureText, isTrue);
    await tester.tap(find.byTooltip('비밀번호 보기'));
    await tester.pump();
    expect(passwordText().obscureText, isFalse);
  });

  testWidgets('키보드가 열린 것처럼 높이가 줄어도 Overflow가 없다', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await _fillValidForm(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('넓은 화면에서는 Form 최대 너비가 560이다', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    expect(tester.getSize(find.byType(Form)).width, lessThanOrEqualTo(560));
  });
}
