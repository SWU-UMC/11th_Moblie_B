import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/main.dart';
import 'package:movielog/screens/sign_up_screen.dart';
import 'package:movielog/utils/sign_up_validators.dart';

Finder _field(String hint) => find.widgetWithText(TextFormField, hint);

ElevatedButton _signUpButton(WidgetTester tester) =>
    tester.widget(find.widgetWithText(ElevatedButton, '가입하기'));

Future<void> _fillValidForm(WidgetTester tester) async {
  await tester.enterText(_field('닉네임을 입력해주세요'), '무비러버');
  await tester.enterText(_field('이메일 주소를 입력해주세요'), 'movie@example.com');
  await tester.enterText(_field('비밀번호를 입력해주세요'), 'password123');
  await tester.pump();
}

void main() {
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

    test('비밀번호는 8자 이상', () {
      expect(SignUpValidators.password(''), '비밀번호를 입력해주세요.');
      expect(SignUpValidators.password('123'), '비밀번호는 8자 이상이어야 합니다.');
      expect(SignUpValidators.password('12345678'), isNull);
    });
  });

  testWidgets('입력 전에는 가입하기 버튼이 비활성화되어 있다', (tester) async {
    await tester.pumpWidget(const MovieLogApp());

    expect(find.byType(SignUpScreen), findsOneWidget);
    expect(_signUpButton(tester).onPressed, isNull);
    expect(find.textContaining('이상이어야 합니다'), findsNothing);
  });

  testWidgets('잘못 입력하면 한국어 오류 메시지가 보인다', (tester) async {
    await tester.pumpWidget(const MovieLogApp());

    await tester.enterText(_field('닉네임을 입력해주세요'), 'a');
    await tester.enterText(_field('이메일 주소를 입력해주세요'), 'test@');
    await tester.enterText(_field('비밀번호를 입력해주세요'), '123');
    await tester.pump();

    expect(find.text('닉네임은 2자 이상이어야 합니다.'), findsOneWidget);
    expect(find.text('올바른 이메일 형식이 아닙니다.'), findsOneWidget);
    expect(find.text('비밀번호는 8자 이상이어야 합니다.'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsNWidgets(3));
    expect(_signUpButton(tester).onPressed, isNull);
  });

  testWidgets('모든 입력이 유효하고 약관에 동의해야 버튼이 활성화된다', (tester) async {
    await tester.pumpWidget(const MovieLogApp());

    await _fillValidForm(tester);
    expect(find.byIcon(Icons.check_circle), findsNWidgets(3));
    expect(_signUpButton(tester).onPressed, isNull);

    await tester.tap(find.text('필수 약관에 동의합니다'));
    await tester.pump();
    expect(_signUpButton(tester).onPressed, isNotNull);

    await tester.tap(find.text('가입하기'));
    await tester.pump();
    expect(find.text('무비러버님, 가입을 환영해요!'), findsOneWidget);
  });

  testWidgets('비밀번호 표시·숨김 버튼으로 obscureText가 바뀐다', (tester) async {
    await tester.pumpWidget(const MovieLogApp());

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

    await tester.pumpWidget(const MovieLogApp());
    await _fillValidForm(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('넓은 화면에서는 Form 최대 너비가 560이다', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MovieLogApp());
    expect(tester.getSize(find.byType(Form)).width, lessThanOrEqualTo(560));
  });
}
