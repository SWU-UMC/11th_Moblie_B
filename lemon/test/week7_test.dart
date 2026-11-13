import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:movielog/core/network/movie_log_client.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/models/sign_up_models.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/sign_up_service.dart';
import 'package:movielog/main.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/screens/signup_screen.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/view_models/learning_member_session.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/view_models/signup_view_model.dart';
import 'package:movielog/widgets/loading_overlay.dart';
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

    test('signUp posts the body and reads memberId from result', () async {
      adapter = _ScriptedAdapter([
        _Reply(
          201,
          '{"isSuccess":true,"code":"COMMON201","message":"회원가입에 성공했습니다.",'
          '"result":{"memberId":31,"email":"movie@umc.com","nickname":"영화광"}}',
        ),
      ]);
      final response = await SignUpService(dio()).signUp(
        const CreateMemberRequest(
          email: 'movie@umc.com',
          password: 'Umc1234!',
          nickname: '영화광',
        ),
      );

      expect(adapter.requests.single, ('POST', '/v6/members'));
      expect(jsonDecode(adapter.bodies.single), {
        'email': 'movie@umc.com',
        'password': 'Umc1234!',
        'nickname': '영화광',
      });
      expect(response.result?.memberId, 31);
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

    test('create, update, delete use their own method and path', () async {
      adapter = _ScriptedAdapter([
        _Reply(
          201,
          '{"isSuccess":true,"code":"COMMON201",'
          '"message":"평점 등록에 성공했습니다.","result":null}',
        ),
        _Reply(
          200,
          '{"isSuccess":true,"code":"COMMON200",'
          '"message":"평점 수정에 성공했습니다.","result":null}',
        ),
        // 204는 body가 없습니다. JSON으로 파싱하면 안 됩니다.
        _Reply(204, ''),
      ]);
      final service = RatingApiService(dio());

      await service.createRating(
        memberId: 31,
        request: const CreateRatingRequest(movieId: 550, score: 5),
      );
      await service.updateRating(
        memberId: 31,
        ratingId: 9,
        score: 4,
        comment: null,
      );
      await service.deleteRating(memberId: 31, ratingId: 9);

      expect(adapter.requests, [
        ('POST', '/v6/members/31/ratings'),
        ('PATCH', '/v6/members/31/ratings/9'),
        ('DELETE', '/v6/members/31/ratings/9'),
      ]);
      expect(jsonDecode(adapter.bodies[0]), {'movieId': 550, 'score': 5});
      // PATCH는 전체 교체라 comment를 명시적으로 보냅니다.
      expect(jsonDecode(adapter.bodies[1]), {'score': 4, 'comment': null});
    });

    test('403/404 refresh the list, 400/409 do not', () {
      DioException error(int status, String code) =>
          fakeCommonError('/v6', status, code, 'message $code');

      expect(shouldRefreshAfterRatingError(error(403, 'COMMON403')), isTrue);
      expect(shouldRefreshAfterRatingError(error(404, 'COMMON404')), isTrue);
      expect(shouldRefreshAfterRatingError(error(400, 'COMMON400')), isFalse);
      expect(shouldRefreshAfterRatingError(error(409, 'COMMON409')), isFalse);
      expect(writeErrorMessage(error(404, 'COMMON404')), 'message COMMON404');
      expect(
        writeErrorMessage(fakeDioError('/v6')),
        '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.',
      );
    });
  });

  group('Sign up submit', () {
    late FakeSignUpService service;
    late LearningMemberSession session;

    Finder field(int index) => find.byType(TextFormField).at(index);

    Future<void> pumpSignup(WidgetTester tester) async {
      useTallScreen(tester);
      session = LearningMemberSession();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: session,
          child: MaterialApp(
            theme: AppTheme.light,
            home: ChangeNotifierProvider(
              create: (_) => SignUpViewModel(service),
              child: const SignupScreen(),
            ),
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
      expect(session.memberId, isNull);
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

    testWidgets('success stores memberId in the learning session', (
      tester,
    ) async {
      service = FakeSignUpService(memberId: 77);
      final router = createAppRouter(initialLocation: '/signup');
      useTallScreen(tester);
      await tester.pumpWidget(
        MovieLogApp(
          router: router,
          movieService: FakeMovieLookupService(),
          signUpService: service,
          ratingApiService: FakeRatingApiService((_) async => const []),
        ),
      );
      await tester.pumpAndSettle();
      await fillAndCheck(tester);
      await tester.tap(find.text('가입하기'));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/movies');
      final context = tester.element(find.byType(Scaffold).first);
      expect(context.read<LearningMemberSession>().memberId, 77);
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

  group('Movie detail rating', () {
    Future<FakeRatingApiService> pumpDetail(
      WidgetTester tester, {
      int? memberId,
      Future<void> Function(int, CreateRatingRequest)? onCreate,
      List<RatingDto>? store,
    }) async {
      useTallScreen(tester);
      final ratings = store ?? <RatingDto>[];
      final ratingService = FakeRatingApiService(
        (_) async => List.of(ratings),
        onCreate:
            onCreate ??
            (_, request) async => ratings.add(
              fakeRating(
                ratings.length + 1,
                request.movieId,
                request.score,
                comment: request.comment,
              ),
            ),
      );
      final router = createAppRouter(initialLocation: '/movies/550');
      await tester.pumpWidget(
        MovieLogApp(
          router: router,
          movieService: FakeMovieLookupService(
            movies: {550: fakeMovie(550, '파이트 클럽')},
          ),
          signUpService: FakeSignUpService(),
          ratingApiService: ratingService,
          initialMemberId: memberId,
        ),
      );
      await tester.pumpAndSettle();
      return ratingService;
    }

    FilledButton rateButton(WidgetTester tester) => tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('평점 남기기'),
        matching: find.byType(FilledButton),
      ),
    );

    testWidgets('without sign up the rate button is disabled', (tester) async {
      await pumpDetail(tester);
      expect(find.text('파이트 클럽'), findsOneWidget);
      expect(find.text('평점을 남기려면 학습용 회원가입이 필요해요.'), findsOneWidget);
      expect(rateButton(tester).onPressed, isNull);
    });

    testWidgets('create shows snackbar, then my page GET shows it', (
      tester,
    ) async {
      final ratingService = await pumpDetail(tester, memberId: 42);

      await tester.tap(find.text('평점 남기기'));
      await tester.pumpAndSettle();
      await tester.tap(emptyStars().at(3));
      await tester.enterText(commentField(), '다시 봐도 좋아요');
      await tester.tap(dialogButton('확인'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text('평점을 등록했습니다. 마이페이지의 "내가 등록한 평점"에서 확인할 수 있습니다.'),
        findsOneWidget,
      );
      final (memberId, request) = ratingService.creates.single;
      expect(memberId, 42);
      expect(request.toJson(), {
        'movieId': 550,
        'score': 4,
        'comment': '다시 봐도 좋아요',
      });

      // 마이페이지 목록은 같은 학습용 회원으로 다시 조회합니다.
      final context = tester.element(find.byType(Scaffold).first);
      GoRouterHelper(context).go('/my');
      await tester.pumpAndSettle();
      // 떠 있는 Snackbar가 사라진 뒤 "내가 등록한 평점" 행을 누릅니다.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.tap(find.text('내가 등록한 평점'));
      await tester.pumpAndSettle();
      expect(ratingService.memberIds, [42]);
      expect(find.text('별점 4 / 5'), findsOneWidget);
      expect(find.text('다시 봐도 좋아요'), findsOneWidget);
    });

    testWidgets('409 keeps the dialog open with the server message', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        memberId: 42,
        onCreate: (_, _) async => throw fakeCommonError(
          '/v6/members/42/ratings',
          409,
          'COMMON409',
          '이미 이 영화에 평점을 남기셨습니다.',
        ),
      );
      await tester.tap(find.text('평점 남기기'));
      await tester.pumpAndSettle();
      await tester.tap(emptyStars().last);
      await tester.enterText(commentField(), '최고');
      await tester.tap(dialogButton('확인'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('이미 이 영화에 평점을 남기셨습니다.'), findsOneWidget);
      expect(find.text('최고'), findsOneWidget);
      expect(find.textContaining('평점을 등록했습니다.'), findsNothing);
    });
  });

  group('My ratings write', () {
    late List<RatingDto> store;
    late FakeRatingApiService ratingService;
    var failNextGet = false;

    Future<void> pumpRatings(WidgetTester tester) async {
      useTallScreen(tester);
      final router = createAppRouter(initialLocation: '/my/ratings');
      await tester.pumpWidget(
        MovieLogApp(
          router: router,
          movieService: FakeMovieLookupService(
            movies: {
              550: fakeMovie(550, '파이트 클럽'),
              13: fakeMovie(13, '포레스트 검프'),
              27205: fakeMovie(27205, '인셉션'),
            },
          ),
          signUpService: FakeSignUpService(),
          ratingApiService: ratingService,
          initialMemberId: 42,
        ),
      );
      await tester.pumpAndSettle();
    }

    setUp(() {
      failNextGet = false;
      store = [
        fakeRating(1, 550, 5, comment: '좋은 영화였어요'),
        fakeRating(2, 13, 4, comment: '다시 봐도 좋아요'),
      ];
      ratingService = FakeRatingApiService(
        (memberId) async {
          if (failNextGet) {
            failNextGet = false;
            throw fakeDioError('/v6/members/$memberId/ratings');
          }
          return List.of(store);
        },
        onUpdate: (ratingId, score, comment) async {
          final index = store.indexWhere((r) => r.ratingId == ratingId);
          final old = store[index];
          store[index] = fakeRating(
            ratingId,
            old.movieId,
            score,
            comment: comment,
          );
        },
        onDelete: (ratingId) async =>
            store.removeWhere((r) => r.ratingId == ratingId),
      );
    });

    Finder cardButton(String label, int index) =>
        find.widgetWithText(TextButton, label).at(index);

    testWidgets('edit/delete buttons sit on the right of each card', (
      tester,
    ) async {
      await pumpRatings(tester);
      expect(find.byType(NavigationBar), findsNothing);
      final title = tester.getRect(find.text('파이트 클럽'));
      final edit = tester.getRect(cardButton('수정', 0));
      final delete = tester.getRect(cardButton('삭제', 0));
      expect(edit.left, greaterThan(title.right));
      expect(delete.top, greaterThan(edit.bottom));
      expect(delete.left, edit.left);
    });

    test('a write finishing after leaving the screen is ignored', () async {
      final gate = Completer<void>();
      ratingService.onUpdate = (_, _, _) => gate.future;
      final viewModel = MyRatingsViewModel(
        ratingService,
        FakeMovieLookupService(),
        42,
      );
      final pending = viewModel.updateRating(ratingId: 1, score: 3);
      viewModel.dispose(); // 응답이 오기 전에 화면을 벗어난 상황입니다.
      gate.complete();
      await pending;

      // 저장 요청은 이미 서버에 갔지만, 사라진 화면의 목록은 다시 읽지 않습니다.
      expect(ratingService.log, ['PATCH 1']);
    });

    testWidgets('edit opens prefilled, PATCH then GET', (tester) async {
      await pumpRatings(tester);
      expect(find.text('학습용 회원(memberId 42)의 평점입니다.'), findsOneWidget);

      await tester.tap(cardButton('수정', 0));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('좋은 영화였어요'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byIcon(Icons.star_rounded),
        ),
        findsNWidgets(5),
      );

      await tester.tap(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byIcon(Icons.star_rounded),
            )
            .at(2),
      );
      await tester.enterText(commentField(), '두 번째는 조금 아쉬워요');
      await tester.tap(dialogButton('확인'));
      await tester.pumpAndSettle();

      expect(ratingService.updates.single, (42, 1, 3, '두 번째는 조금 아쉬워요'));
      expect(ratingService.log, ['GET', 'PATCH 1', 'GET']);
      expect(find.text('별점 3 / 5'), findsOneWidget);
      expect(find.text('두 번째는 조금 아쉬워요'), findsOneWidget);
      expect(find.text('평점을 수정했습니다.'), findsOneWidget);
    });

    testWidgets('delete cancel sends nothing, delete success refreshes', (
      tester,
    ) async {
      await pumpRatings(tester);

      await tester.tap(cardButton('삭제', 0));
      await tester.pumpAndSettle();
      expect(find.text('평점을 삭제할까요?'), findsOneWidget);
      expect(find.text('삭제한 평점은 복구할 수 없습니다.'), findsOneWidget);
      await tester.tap(dialogButton('취소'));
      await tester.pumpAndSettle();
      expect(ratingService.deletes, isEmpty);
      expect(find.text('파이트 클럽'), findsOneWidget);

      await tester.tap(cardButton('삭제', 0));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('삭제'));
      await tester.pumpAndSettle();
      expect(ratingService.log, ['GET', 'DELETE 1', 'GET']);
      expect(find.text('파이트 클럽'), findsNothing);
      expect(find.text('평점을 삭제했습니다.'), findsOneWidget);

      await tester.tap(cardButton('삭제', 0));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('삭제'));
      await tester.pumpAndSettle();
      expect(find.text('아직 등록한 평점이 없어요.'), findsOneWidget);
    });

    testWidgets('save success + GET failure retries only the GET', (
      tester,
    ) async {
      await pumpRatings(tester);
      failNextGet = true;

      await tester.tap(cardButton('수정', 1));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('확인'));
      await tester.pumpAndSettle();

      // 저장은 성공했으므로 Dialog는 닫히고, 목록에는 조회 재시도 안내만 남습니다.
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text('저장은 완료됐지만 목록을 불러오지 못했습니다. 조회만 다시 시도해 주세요.'),
        findsOneWidget,
      );

      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(ratingService.log, ['GET', 'PATCH 2', 'GET', 'GET']);
      expect(find.text('포레스트 검프'), findsOneWidget);
      expect(find.textContaining('저장은 완료됐지만'), findsNothing);
    });

    testWidgets('403 on update shows its message and resyncs the list', (
      tester,
    ) async {
      ratingService.onUpdate = (_, _, _) async => throw fakeCommonError(
        '/v6/members/42/ratings/1',
        403,
        'COMMON403',
        '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.',
      );
      await pumpRatings(tester);
      await tester.tap(cardButton('수정', 0));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('확인'));
      await tester.pumpAndSettle();

      expect(find.text('본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.'), findsOneWidget);
      expect(find.text('좋은 영화였어요'), findsWidgets);
      expect(ratingService.log, ['GET', 'PATCH 1', 'GET']);
    });

    testWidgets('multi delete shows overlay and keeps failed selection', (
      tester,
    ) async {
      store.add(fakeRating(3, 27205, 3));
      final gate = Completer<void>();
      ratingService.onDelete = (ratingId) async {
        await gate.future;
        if (ratingId == 2) {
          throw fakeCommonError(
            '/v6/members/42/ratings/2',
            404,
            'COMMON404',
            '존재하지 않는 평점입니다.',
          );
        }
        store.removeWhere((r) => r.ratingId == ratingId);
      };
      await pumpRatings(tester);

      await tester.tap(find.text('선택 삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('파이트 클럽 · 별점 5'));
      await tester.tap(find.text('포레스트 검프 · 별점 4'));
      await tester.pump();
      expect(find.text('2개 선택됨'), findsOneWidget);

      await tester.tap(find.text('선택한 2개 삭제'));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('삭제'));
      await tester.pump();
      // 인디케이터가 계속 돌아 pumpAndSettle 대신 Dialog 닫힘 애니메이션 시간만큼 진행합니다.
      await tester.pump(const Duration(milliseconds: 500));

      // 확인 Dialog는 닫히고, 화면 위 오버레이가 삭제 진행을 보여줍니다.
      expect(find.byType(AlertDialog), findsNothing);
      final overlay = tester.widget<LoadingOverlay>(
        find.byType(LoadingOverlay),
      );
      expect(overlay.isLoading, isTrue);
      expect(find.byType(ModalBarrier), findsWidgets);

      gate.complete();
      await tester.pumpAndSettle();

      expect(
        tester.widget<LoadingOverlay>(find.byType(LoadingOverlay)).isLoading,
        isFalse,
      );
      expect(ratingService.deletes, [(42, 1), (42, 2)]);
      // 삭제가 끝난 뒤 서버 목록을 다시 조회합니다.
      expect(ratingService.log, ['GET', 'DELETE 1', 'DELETE 2', 'GET']);
      expect(find.text('파이트 클럽 · 별점 5'), findsNothing);
      // 실패한 항목은 선택 상태로 남습니다.
      expect(find.text('1개 선택됨'), findsOneWidget);
      expect(find.text('1개 항목을 삭제하지 못했습니다: 존재하지 않는 평점입니다.'), findsOneWidget);
    });
  });

  group('CodeRabbit review fixes', () {
    test('403/404 refresh even without a common body', () {
      expect(
        shouldRefreshAfterRatingError(fakeDioError('/v6', statusCode: 404)),
        isTrue,
      );
      expect(
        shouldRefreshAfterRatingError(fakeDioError('/v6', statusCode: 403)),
        isTrue,
      );
      expect(
        shouldRefreshAfterRatingError(fakeDioError('/v6', statusCode: 500)),
        isFalse,
      );
    });

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

    testWidgets('card buttons keep their tap action for screen readers', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      useTallScreen(tester);
      await tester.pumpWidget(
        MovieLogApp(
          router: createAppRouter(initialLocation: '/my/ratings'),
          movieService: FakeMovieLookupService(
            movies: {550: fakeMovie(550, '파이트 클럽')},
          ),
          signUpService: FakeSignUpService(),
          ratingApiService: FakeRatingApiService(
            (_) async => [fakeRating(1, 550, 5)],
          ),
          initialMemberId: 42,
        ),
      );
      await tester.pumpAndSettle();

      for (final label in ['파이트 클럽 평점 수정', '파이트 클럽 평점 삭제']) {
        expect(
          tester.getSemantics(find.bySemanticsLabel(label)),
          isSemantics(label: label, isButton: true, hasTapAction: true),
        );
      }
      semantics.dispose();
    });

    testWidgets('another movie id gets a fresh detail screen', (tester) async {
      useTallScreen(tester);
      final router = createAppRouter(initialLocation: '/movies/550');
      await tester.pumpWidget(
        MovieLogApp(
          router: router,
          movieService: FakeMovieLookupService(
            movies: {
              550: fakeMovie(550, '파이트 클럽'),
              13: fakeMovie(13, '포레스트 검프'),
            },
          ),
          signUpService: FakeSignUpService(),
          ratingApiService: FakeRatingApiService((_) async => const []),
          initialMemberId: 42,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('파이트 클럽'), findsOneWidget);

      router.go('/movies/13');
      await tester.pumpAndSettle();
      expect(find.text('포레스트 검프'), findsOneWidget);
      expect(find.text('파이트 클럽'), findsNothing);
    });

    group('bulk delete outcomes', () {
      late FakeRatingApiService service;
      late List<RatingDto> store;

      MyRatingsViewModel viewModel() =>
          MyRatingsViewModel(service, FakeMovieLookupService(), 42);

      setUp(() {
        store = [fakeRating(1, 550, 5), fakeRating(2, 13, 4)];
        service = FakeRatingApiService((_) async => List.of(store));
      });

      test('an unexpected response does not stop the batch', () async {
        service.onDelete = (ratingId) async {
          if (ratingId == 1) throw StateError('예상하지 못한 삭제 응답: 200');
          store.removeWhere((r) => r.ratingId == ratingId);
        };
        final vm = viewModel();
        await vm.load();
        vm
          ..startSelection()
          ..toggleSelection(1)
          ..toggleSelection(2);

        final result = await vm.deleteSelectedRatings();
        expect(result.deleted, 1);
        expect(result.failed, 1);
        expect(service.log, ['GET', 'DELETE 1', 'DELETE 2', 'GET']);
        expect(vm.selectedRatingIds, {1});
        expect(vm.isDeletingSelected, isFalse);
      });

      test('nothing deleted: no "saved" warning, no reload on network '
          'failure', () async {
        service.onDelete = (ratingId) async =>
            throw fakeDioError('/v6/members/42/ratings/$ratingId');
        final vm = viewModel();
        await vm.load();
        vm
          ..startSelection()
          ..toggleSelection(1);

        final result = await vm.deleteSelectedRatings();
        expect(result.deleted, 0);
        expect(result.messages, ['요청에 실패했습니다. 잠시 후 다시 시도해 주세요.']);
        expect(service.log, ['GET', 'DELETE 1']);
        expect(vm.refreshWarning, isNull);
        expect(vm.status, MyRatingsLoadStatus.success);
      });

      test(
        'nothing deleted but 404: resync without a "saved" warning',
        () async {
          service.onDelete = (ratingId) async => throw fakeCommonError(
            '/v6/members/42/ratings/$ratingId',
            404,
            'COMMON404',
            '존재하지 않는 평점입니다.',
          );
          final vm = viewModel();
          await vm.load();
          vm
            ..startSelection()
            ..toggleSelection(1);

          final result = await vm.deleteSelectedRatings();
          expect(result.messages, ['존재하지 않는 평점입니다.']);
          expect(service.log, ['GET', 'DELETE 1', 'GET']);
          expect(vm.refreshWarning, isNull);
        },
      );
    });
  });

  testWidgets('my ratings asks for sign up without a member', (tester) async {
    useTallScreen(tester);
    final ratingService = FakeRatingApiService((_) async => const []);
    await tester.pumpWidget(
      MovieLogApp(
        router: createAppRouter(initialLocation: '/my/ratings'),
        movieService: FakeMovieLookupService(),
        signUpService: FakeSignUpService(),
        ratingApiService: ratingService,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('학습용 회원가입이 필요합니다.'), findsOneWidget);
    // 6주차 memberId 1로 대신 조회하지 않습니다.
    expect(ratingService.memberIds, isEmpty);
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
