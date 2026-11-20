import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:movielog/core/network/movie_log_client.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/models/sign_up_models.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/sign_up_service.dart';
import 'package:movielog/screens/signup_screen.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/view_models/signup_view_model.dart';
import 'package:movielog/widgets/movielog_button.dart';
import 'package:movielog/widgets/rating_dialog.dart';

import 'fakes/movie_log_fakes.dart';

void main() {
  // 영화 탭의 장르 저장소를 테스트마다 비어 있는 메모리 저장소로 바꿉니다.
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  void useTallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Finder dialogButton(String label) => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.widgetWithText(MovieLogButton, label),
  );
  MovieLogButton button(WidgetTester tester, Finder finder) =>
      tester.widget<MovieLogButton>(finder);
  Finder emptyStars() => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byIcon(Icons.star_outline_rounded),
  );
  Finder commentField() => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextField),
  );

  group('Models', () {
    test('CommonResponse parses result once and null result', () {
      final signUp = CommonResponse<SignUpResult>.fromJson({
        'isSuccess': true,
        'code': 'COMMON201',
        'message': '회원가입에 성공했습니다.',
        'result': {'memberId': 7, 'email': 'a@b.com', 'nickname': '영화광'},
      }, (value) => SignUpResult.fromJson(value as Map<String, dynamic>));
      expect(signUp.result?.memberId, 7);

      final patched = CommonResponse<Object?>.fromJson({
        'isSuccess': true,
        'code': 'COMMON200',
        'message': '평점 수정에 성공했습니다.',
        'result': null,
      }, (value) => value);
      expect(patched.result, isNull);
      expect(CommonResponse.tryParseError('not json'), isNull);
    });

    test('CreateMemberRequest trims ids but never the password', () {
      const request = CreateMemberRequest(
        email: ' movie@umc.com ',
        password: ' Umc1234! ',
        nickname: ' 영화광 ',
      );
      expect(request.toJson(), {
        'email': 'movie@umc.com',
        'password': ' Umc1234! ',
        'nickname': '영화광',
      });
      // 디버그 출력에도 비밀번호가 남지 않습니다.
      expect(request.toString(), isNot(contains('Umc1234')));
    });

    test('CreateRatingRequest omits empty comment, score must be 1~5 int', () {
      expect(
        const CreateRatingRequest(
          movieId: 550,
          score: 4,
          comment: '  ',
        ).toJson(),
        {'movieId': 550, 'score': 4},
      );
      expect(
        const CreateRatingRequest(
          movieId: 550,
          score: 4,
          comment: ' 좋아요 ',
        ).toJson(),
        {'movieId': 550, 'score': 4, 'comment': '좋아요'},
      );
      expect(validateServerScore(3), 3);
      expect(() => validateServerScore(3.5), throwsArgumentError);
      expect(() => validateServerScore(0), throwsArgumentError);
      expect(() => validateServerScore(6), throwsArgumentError);
    });
  });

  group('Real v6 write services', () {
    late _ScriptedAdapter adapter;

    Dio dio() =>
        Dio(BaseOptions(baseUrl: 'https://workbook.devnoco.com'))
          ..httpClientAdapter = adapter;

    test('MovieLog client never carries the TMDB token', () {
      final client = createMovieLogClient();
      expect(client.options.baseUrl, 'https://workbook.devnoco.com');
      expect(client.options.headers.keys, isNot(contains('Authorization')));
      expect(client.interceptors.whereType<LogInterceptor>(), isEmpty);
    });

    test('409 sign up error uses the server message', () async {
      adapter = _ScriptedAdapter([
        _Reply(
          409,
          '{"isSuccess":false,"code":"COMMON409",'
          '"message":"이미 사용 중인 이메일입니다.","result":null}',
        ),
      ]);
      try {
        await SignUpService(dio()).signUp(
          const CreateMemberRequest(
            email: 'movie@umc.com',
            password: 'Umc1234!',
            nickname: '영화광',
          ),
        );
        fail('409 should throw');
      } on DioException catch (error) {
        expect(writeSignUpErrorMessage(error), '이미 사용 중인 이메일입니다.');
      }
    });
  });

  group('Sign up submit', () {
    late FakeSignUpService service;

    Finder field(int index) => find.byType(TextFormField).at(index);

    Future<void> pumpSignup(WidgetTester tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ChangeNotifierProvider(
            create: (_) => SignUpViewModel(service),
            child: const SignupScreen(),
          ),
        ),
      );
    }

    Future<void> fillAndCheck(WidgetTester tester) async {
      await tester.enterText(field(0), '영화광');
      await tester.enterText(field(1), 'movie@umc.com');
      await tester.enterText(field(2), 'Umc1234!');
      await tester.pump();
      await tester.tap(find.text('중복 확인').at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('중복 확인').at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('필수 약관에 동의합니다'));
      await tester.pump();
    }

    MovieLogButton submitButton(WidgetTester tester) => tester
        .widget<MovieLogButton>(find.widgetWithText(MovieLogButton, '가입하기'));

    testWidgets('final 409 shows server message and marks the field', (
      tester,
    ) async {
      final gate = Completer<void>();
      service = FakeSignUpService(
        onSignUp: (_) async {
          await gate.future;
          throw fakeCommonError(
            '/v6/members',
            409,
            'COMMON409',
            '이미 사용 중인 이메일입니다.',
          );
        },
      );
      await pumpSignup(tester);
      await fillAndCheck(tester);
      expect(find.text('사용 가능한 이메일입니다.'), findsOneWidget);

      await tester.tap(find.text('가입하기'));
      await tester.pump();
      // 제출 중에는 회색 인디케이터 버튼이 되고 입력도 막힙니다.
      expect(submitButton(tester).isLoading, isTrue);
      expect(tester.widget<TextFormField>(field(0)).enabled, isFalse);
      // 제출 중 연속 탭은 요청을 다시 보내지 않습니다.
      await tester.tap(find.text('가입하기'), warnIfMissed: false);
      await tester.pump();
      expect(service.signUpCalls, hasLength(1));

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.text('이미 사용 중인 이메일입니다.'), findsNWidgets(2));
      expect(find.byType(SnackBar), findsOneWidget);
      expect(submitButton(tester).onPressed, isNull);
      // 가입 요청에는 사용자가 입력한 비밀번호가 그대로 갑니다.
      expect(service.signUpCalls.single.toJson()['password'], 'Umc1234!');
    });

    testWidgets('server 400 for password shows under the password field', (
      tester,
    ) async {
      service = FakeSignUpService(
        onSignUp: (_) async => throw fakeCommonError(
          '/v6/members',
          400,
          'COMMON400',
          '비밀번호는 대문자/소문자/숫자/특수문자를 포함한 8자 이상이어야 합니다.',
        ),
      );
      await pumpSignup(tester);
      await fillAndCheck(tester);
      await tester.tap(find.text('가입하기'));
      await tester.pumpAndSettle();

      final message = '비밀번호는 대문자/소문자/숫자/특수문자를 포함한 8자 이상이어야 합니다.';
      expect(
        find.descendant(of: field(2), matching: find.text(message)),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);

      // 비밀번호를 고치면 서버 오류가 사라집니다.
      await tester.enterText(field(2), 'Umc1234!!');
      await tester.pump();
      expect(find.text(message), findsNothing);
    });
  });

  group('RatingDialog', () {
    late List<(int, String?)> submits;

    Future<void> pumpDialog(
      WidgetTester tester, {
      int initialScore = 0,
      String? initialComment,
      Future<void> Function(int score, String? comment)? onSubmit,
      void Function(bool? result)? onResult,
    }) async {
      useTallScreen(tester);
      submits = [];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  final result = await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => RatingDialog(
                      initialScore: initialScore,
                      initialComment: initialComment,
                      onSubmit: (score, comment) async {
                        submits.add((score, comment));
                        await onSubmit?.call(score, comment);
                      },
                    ),
                  );
                  onResult?.call(result);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('confirm needs a star even with a comment', (tester) async {
      await pumpDialog(tester);
      expect(find.text('코멘트 (선택, 최대 500자)'), findsOneWidget);
      expect(find.text('이 영화의 인상적인 장면은...'), findsOneWidget);

      await tester.enterText(commentField(), '인상적이었어요');
      await tester.pump();
      expect(button(tester, dialogButton('확인')).onPressed, isNull);

      await tester.tap(emptyStars().at(3));
      await tester.pump();
      expect(button(tester, dialogButton('확인')).onPressed, isNotNull);
    });

    testWidgets('cancel returns false without calling onSubmit', (
      tester,
    ) async {
      bool? result;
      await pumpDialog(tester, onResult: (value) => result = value);
      await tester.tap(emptyStars().at(2));
      await tester.pump();
      await tester.tap(dialogButton('취소'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(submits, isEmpty);
    });

    testWidgets('empty comment becomes null and returns true', (tester) async {
      bool? result;
      await pumpDialog(tester, onResult: (value) => result = value);
      await tester.tap(emptyStars().last);
      await tester.enterText(commentField(), '   ');
      await tester.tap(dialogButton('확인'));
      await tester.pumpAndSettle();

      expect(submits, [(5, null)]);
      expect(result, isTrue);
    });

    testWidgets('saving blocks input, failure keeps the input', (tester) async {
      final gate = Completer<void>();
      await pumpDialog(
        tester,
        onSubmit: (_, _) async {
          await gate.future;
          throw const RatingWriteFailure('이미 이 영화에 평점을 남기셨습니다.');
        },
      );
      await tester.tap(emptyStars().at(3));
      await tester.enterText(commentField(), '다시 봐도 좋아요');
      await tester.tap(dialogButton('확인'));
      await tester.pump();

      expect(button(tester, dialogButton('확인')).isLoading, isTrue);
      expect(button(tester, dialogButton('취소')).onPressed, isNull);
      // 저장 중에는 뒤로 가기로 닫히지 않습니다.
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('이미 이 영화에 평점을 남기셨습니다.'), findsOneWidget);
      expect(find.text('다시 봐도 좋아요'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
      expect(button(tester, dialogButton('확인')).onPressed, isNotNull);
    });

    testWidgets('edit opens with the existing score and comment', (
      tester,
    ) async {
      await pumpDialog(tester, initialScore: 3, initialComment: '무난했어요');
      expect(find.text('무난했어요'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
      expect(button(tester, dialogButton('확인')).onPressed, isNotNull);
    });
  });

  group('CodeRabbit review fixes', () {
    Future<void> pumpRatingDialog(
      WidgetTester tester, {
      required List<(int, String?)> submits,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => RatingDialog(
                    onSubmit: (score, comment) async =>
                        submits.add((score, comment)),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('stars stay on one row on a 320px screen', (tester) async {
      tester.view.physicalSize = const Size(960, 2000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final submits = <(int, String?)>[];
      await pumpRatingDialog(tester, submits: submits);

      final stars = emptyStars();
      expect(stars, findsNWidgets(5));
      final rows = {
        for (var i = 0; i < 5; i++) tester.getCenter(stars.at(i)).dy.round(),
      };
      expect(rows, hasLength(1));
      expect(tester.takeException(), isNull);

      await tester.tap(stars.last);
      await tester.pump();
      await tester.tap(dialogButton('확인'));
      await tester.pumpAndSettle();
      expect(submits, [(5, null)]);
    });

    testWidgets('emoji comment is counted like the server', (tester) async {
      useTallScreen(tester);
      final submits = <(int, String?)>[];
      await pumpRatingDialog(tester, submits: submits);
      final comment = '🎥' * 251;

      await tester.tap(emptyStars().at(2));
      await tester.enterText(commentField(), comment);
      await tester.pump();
      expect(find.text('251/500'), findsOneWidget);

      await tester.tap(dialogButton('확인'));
      await tester.pumpAndSettle();
      expect(submits, [(3, comment)]);

      // 501자를 넘는 입력은 막습니다.
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(commentField(), '🎥' * 501);
      await tester.pump();
      expect(find.text('0/500'), findsOneWidget);
    });
  });
}

class _Reply {
  const _Reply(this.status, this.body);

  final int status;
  final String body;
}

/// 요청 method·경로·body를 기록하고 정해진 순서대로 응답하는 Dio Adapter입니다.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.replies);

  final List<_Reply> replies;
  final requests = <(String, String)>[];
  final bodies = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add((options.method, options.uri.path));
    if (requestStream != null) {
      final chunks = await requestStream.toList();
      bodies.add(utf8.decode(chunks.expand((chunk) => chunk).toList()));
    }
    final reply = replies[requests.length - 1];
    return ResponseBody.fromBytes(
      utf8.encode(reply.body),
      reply.status,
      headers: {
        if (reply.body.isNotEmpty)
          Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
