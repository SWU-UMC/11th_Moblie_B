import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:movielog/data/models/check_result.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/sign_up_service.dart';
import 'package:movielog/main.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/screens/my_ratings_screen.dart';
import 'package:movielog/screens/signup_screen.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/view_models/signup_view_model.dart';
import 'package:movielog/widgets/movielog_button.dart';

import 'fakes/movie_log_fakes.dart';

void main() {
  void useTallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  group('MovieLogButton', () {
    Future<void> pumpButton(WidgetTester tester, Widget button) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(child: SizedBox(width: 300, child: button)),
            ),
          ),
        );

    ElevatedButton elevated(WidgetTester tester) =>
        tester.widget<ElevatedButton>(find.byType(ElevatedButton));

    testWidgets('loading shows only an indicator and is disabled', (
      tester,
    ) async {
      await pumpButton(
        tester,
        MovieLogButton(label: '중복 확인', onPressed: () {}),
      );
      final idleWidth = tester.getSize(find.byType(MovieLogButton)).width;
      expect(elevated(tester).onPressed, isNotNull);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await pumpButton(
        tester,
        MovieLogButton(label: '중복 확인', onPressed: () {}, isLoading: true),
      );
      expect(elevated(tester).onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // label은 그리지 않지만 자리는 유지해 버튼 너비가 바뀌지 않습니다.
      final label = tester.widget<Visibility>(
        find.ancestor(
          of: find.text('중복 확인'),
          matching: find.byType(Visibility),
        ),
      );
      expect(label.visible, isFalse);
      expect(tester.getSize(find.byType(MovieLogButton)).width, idleWidth);
    });

    testWidgets('null onPressed is disabled', (tester) async {
      await pumpButton(
        tester,
        const MovieLogButton(label: '가입하기', onPressed: null),
      );
      expect(elevated(tester).onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('width null uses content size, infinity fills parent', (
      tester,
    ) async {
      await pumpButton(
        tester,
        Align(
          alignment: Alignment.centerLeft,
          child: MovieLogButton(label: '확인', onPressed: () {}),
        ),
      );
      expect(tester.getSize(find.byType(MovieLogButton)).width, lessThan(300));

      await pumpButton(
        tester,
        MovieLogButton(label: '가입하기', width: double.infinity, onPressed: () {}),
      );
      expect(tester.getSize(find.byType(MovieLogButton)).width, 300);
    });
  });

  testWidgets('Button demo shows null, fixed and infinity widths', (
    tester,
  ) async {
    useTallScreen(tester);
    final router = createAppRouter(initialLocation: '/dev/buttons');
    await tester.pumpWidget(
      MovieLogApp(
        router: router,
        movieService: FakeMovieLookupService(),
        signUpService: FakeSignUpService(),
        ratingApiService: FakeRatingApiService((_) async => const []),
      ),
    );
    // 통신 중 예시의 인디케이터가 계속 돌기 때문에 pumpAndSettle 대신 pump를 씁니다.
    await tester.pump();

    double widthOf(String label, int index) => tester
        .getSize(find.widgetWithText(MovieLogButton, label).at(index))
        .width;

    // null: label 길이에 따라 다름 / 고정 값: 항상 120 / infinity: 가장 넓음
    expect(widthOf('확인', 0), lessThan(widthOf('조금 더 긴 라벨', 0)));
    expect(widthOf('확인', 1), 120);
    expect(widthOf('조금 더 긴 라벨', 1), 120);
    final infinity = find.widgetWithText(MovieLogButton, '확인').at(2);
    final parent = find
        .ancestor(of: infinity, matching: find.byType(Container))
        .first;
    // 테두리(1) + 안쪽 여백(8)을 뺀 부모 영역을 모두 사용합니다.
    expect(widthOf('확인', 2), tester.getSize(parent).width - 18);
  });

  group('Signup duplicate check', () {
    late FakeSignUpService service;

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

    Finder field(int index) => find.byType(TextFormField).at(index);
    Finder checkButton(int index) => find.byType(MovieLogButton).at(index);
    MovieLogButton button(WidgetTester tester, int index) =>
        tester.widget<MovieLogButton>(checkButton(index));

    testWidgets('idle -> checking -> available, then reset on edit', (
      tester,
    ) async {
      service = FakeSignUpService();
      await pumpSignup(tester);

      await tester.enterText(field(0), '무비러버');
      await tester.pump();
      expect(button(tester, 0).onPressed, isNotNull);

      service.gate = Completer<void>();
      await tester.tap(checkButton(0));
      await tester.pump();
      expect(find.text('닉네임 사용 여부를 확인 중입니다.'), findsOneWidget);
      expect(button(tester, 0).isLoading, isTrue);

      service.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('사용 가능한 닉네임입니다.'), findsOneWidget);
      expect(service.nicknameCalls, ['무비러버']);

      // 입력을 바꾸면 이전 결과는 사라집니다.
      await tester.enterText(field(0), '무비러버2');
      await tester.pump();
      expect(find.text('사용 가능한 닉네임입니다.'), findsNothing);
      expect(button(tester, 0).onPressed, isNotNull);
    });

    testWidgets('re-entering a duplicated value shows error without API', (
      tester,
    ) async {
      service = FakeSignUpService(taken: {'영화광'});
      await pumpSignup(tester);

      await tester.enterText(field(0), '영화광');
      await tester.pump();
      await tester.tap(checkButton(0));
      await tester.pumpAndSettle();
      expect(find.text('이미 사용 중인 닉네임입니다.'), findsOneWidget);
      expect(button(tester, 0).onPressed, isNull);

      await tester.enterText(field(0), '영화광2');
      await tester.pump();
      expect(find.text('이미 사용 중인 닉네임입니다.'), findsNothing);
      expect(button(tester, 0).onPressed, isNotNull);

      await tester.enterText(field(0), '영화광');
      await tester.pump();
      expect(find.text('이미 사용 중인 닉네임입니다.'), findsOneWidget);
      expect(service.nicknameCalls, ['영화광']);
    });

    testWidgets('network failure differs from duplicated', (tester) async {
      service = FakeSignUpService(fail: true);
      await pumpSignup(tester);

      await tester.enterText(field(1), 'movie@umc.com');
      await tester.pump();
      await tester.tap(checkButton(1));
      await tester.pumpAndSettle();

      expect(find.text('중복 확인에 실패했습니다. 다시 시도해 주세요.'), findsOneWidget);
      expect(find.text('이미 사용 중인 이메일입니다.'), findsNothing);
      // 통신 실패는 다시 시도할 수 있습니다.
      expect(button(tester, 1).onPressed, isNotNull);
    });

    testWidgets('response for an old input is ignored', (tester) async {
      service = FakeSignUpService();
      await pumpSignup(tester);

      await tester.enterText(field(0), '무비러버');
      await tester.pump();
      service.gate = Completer<void>();
      await tester.tap(checkButton(0));
      await tester.pump();
      expect(button(tester, 0).isLoading, isTrue);

      await tester.enterText(field(0), '무비러버2');
      service.gate!.complete();
      await tester.pumpAndSettle();

      expect(find.text('사용 가능한 닉네임입니다.'), findsNothing);
      expect(button(tester, 0).isLoading, isFalse);
    });

    testWidgets('nickname and email results stay separate', (tester) async {
      service = FakeSignUpService(taken: {'영화광'});
      await pumpSignup(tester);

      await tester.enterText(field(0), '영화광');
      await tester.enterText(field(1), 'movie@umc.com');
      await tester.pump();
      await tester.tap(checkButton(0));
      await tester.pumpAndSettle();
      await tester.tap(checkButton(1));
      await tester.pumpAndSettle();

      expect(find.text('이미 사용 중인 닉네임입니다.'), findsOneWidget);
      expect(find.text('사용 가능한 이메일입니다.'), findsOneWidget);
    });

    testWidgets('check button stays beside the field', (tester) async {
      service = FakeSignUpService();
      await pumpSignup(tester);

      final fieldBox = tester.getRect(field(0));
      final buttonBox = tester.getRect(checkButton(0));
      expect(buttonBox.left - fieldBox.right, 8);
      expect(buttonBox.top, fieldBox.top);
    });

    testWidgets('check button moves below the field when the row is narrow', (
      tester,
    ) async {
      service = FakeSignUpService();
      tester.view.physicalSize = const Size(960, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ChangeNotifierProvider(
            create: (_) => SignUpViewModel(service),
            child: const SignupScreen(),
          ),
        ),
      );

      final fieldBox = tester.getRect(field(0));
      final buttonBox = tester.getRect(checkButton(0));
      // 입력창은 전체 너비를 쓰고, 버튼은 그 아래에 놓입니다.
      expect(buttonBox.top, greaterThan(fieldBox.bottom));
      expect(fieldBox.width, greaterThan(200));
      expect(tester.takeException(), isNull);
    });
  });

  group('My ratings', () {
    late FakeRatingApiService ratingService;
    late FakeMovieLookupService movieService;

    setUp(() {
      movieService = FakeMovieLookupService(
        movies: {550: fakeMovie(550, '파이트 클럽')},
      );
    });

    Future<void> pumpRatings(WidgetTester tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ChangeNotifierProvider(
            create: (_) =>
                MyRatingsViewModel(ratingService, movieService, 1)..load(),
            child: const MyRatingsScreen(),
          ),
        ),
      );
    }

    testWidgets('opens from profile without NavigationBar and goes back', (
      tester,
    ) async {
      useTallScreen(tester);
      ratingService = FakeRatingApiService((_) async => const []);
      final router = createAppRouter(initialLocation: '/my');
      await tester.pumpWidget(
        MovieLogApp(
          router: router,
          movieService: movieService,
          signUpService: FakeSignUpService(),
          ratingApiService: ratingService,
          initialMemberId: 1,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);

      await tester.tap(find.text('내가 등록한 평점'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/my/ratings');
      expect(find.byType(MyRatingsScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(ratingService.memberIds, [1]);

      await tester.tap(find.byTooltip('뒤로 가기'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/my');
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('loading then success with TMDB title and placeholder', (
      tester,
    ) async {
      final gate = Completer<void>();
      ratingService = FakeRatingApiService((_) async {
        await gate.future;
        return [
          fakeRating(1, 550, 5, comment: '최고의 영화!'),
          fakeRating(2, 13, 3),
          fakeRating(3, 550, 4, comment: '다시 봐도 좋다'),
        ];
      });
      await pumpRatings(tester);
      expect(find.text('평점을 불러오고 있어요'), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.text('파이트 클럽'), findsNWidgets(2));
      expect(find.text('별점 5 / 5'), findsOneWidget);
      expect(find.text('최고의 영화!'), findsOneWidget);
      // TMDB에서 찾지 못한 영화도 평점은 그대로 보여줍니다.
      expect(find.text('영화 #13'), findsOneWidget);
      expect(find.text('포스터 정보 없음'), findsOneWidget);
      expect(find.text('별점 3 / 5'), findsOneWidget);
      // 화면은 기기 시간대로 날짜를 보여주므로, 기대값도 같은 시각을 toLocal()로 계산합니다.
      final local = fakeRating(1, 550, 5).createdAt.toLocal();
      String two(int value) => value.toString().padLeft(2, '0');
      final expectedDate =
          '${local.year}.${two(local.month)}.${two(local.day)} 등록';
      expect(find.text(expectedDate, skipOffstage: false), findsWidgets);
      expect(find.text('일부 영화 정보를 가져오지 못해 제목·포스터를 대신 표시합니다.'), findsOneWidget);
      // 같은 movieId(550)는 한 번만 조회합니다.
      expect(movieService.lookups.where((id) => id == 550), hasLength(1));
    });

    testWidgets('empty list shows empty view', (tester) async {
      ratingService = FakeRatingApiService((_) async => const []);
      await pumpRatings(tester);
      await tester.pumpAndSettle();
      expect(find.text('아직 등록한 평점이 없어요.'), findsOneWidget);
      expect(find.text('학습용 회원(memberId 1)의 평점입니다.'), findsOneWidget);
    });

    testWidgets('404 shows member message and retry recovers', (tester) async {
      var calls = 0;
      ratingService = FakeRatingApiService((memberId) async {
        calls++;
        if (calls == 1) {
          throw fakeDioError('/v6/members/$memberId/ratings', statusCode: 404);
        }
        return [fakeRating(1, 550, 5)];
      });
      await pumpRatings(tester);
      await tester.pumpAndSettle();
      expect(find.text('존재하지 않는 회원입니다.'), findsOneWidget);
      expect(find.text('학습용 회원(memberId 1)의 평점입니다.'), findsOneWidget);

      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(find.text('파이트 클럽'), findsOneWidget);
    });

    testWidgets('TMDB failure keeps ratings and is retried next load', (
      tester,
    ) async {
      movieService.failingIds = {550};
      ratingService = FakeRatingApiService(
        (_) async => [fakeRating(1, 550, 5)],
      );
      await pumpRatings(tester);
      await tester.pumpAndSettle();
      expect(find.text('영화 #550'), findsOneWidget);
      expect(find.text('별점 5 / 5'), findsOneWidget);

      // 일시적인 실패는 캐시하지 않으므로, 화면의 "다시 불러오기"로 영화를 다시 찾습니다.
      movieService.failingIds = {};
      await tester.tap(find.text('다시 불러오기'));
      await tester.pumpAndSettle();
      expect(find.text('파이트 클럽'), findsOneWidget);
      expect(find.text('다시 불러오기'), findsNothing);
    });

    testWidgets('malformed response shows error view', (tester) async {
      ratingService = FakeRatingApiService((_) async => throw TypeError());
      await pumpRatings(tester);
      await tester.pumpAndSettle();
      expect(find.text('다시 시도'), findsOneWidget);
    });
  });

  group('Real v6 read services', () {
    late _RecordingAdapter adapter;

    Dio dio() =>
        Dio(BaseOptions(baseUrl: 'https://workbook.devnoco.com'))
          ..httpClientAdapter = adapter;

    test('checkNickname and checkEmail request their own paths', () async {
      adapter = _RecordingAdapter('{"available": false}');
      final service = SignUpService(dio());

      expect(await service.checkNickname(' 영화광 '), isFalse);
      expect(await service.checkEmail('movie@umc.com'), isFalse);

      // 앞뒤 공백은 지우고, 경로에 들어가는 값은 인코딩합니다.
      expect(adapter.paths, [
        '/v6/members/nickname/${Uri.encodeComponent('영화광')}',
        '/v6/members/email/movie%40umc.com',
      ]);
    });

    test('fetchMyRatings requests the member ratings path', () async {
      adapter = _RecordingAdapter(
        '[{"ratingId":1,"movieId":550,"score":5,"comment":null,'
        '"createdAt":"2026-11-01T19:00:27.956Z"}]',
      );
      final ratings = await RatingApiService(dio()).fetchMyRatings(1);

      expect(adapter.paths, ['/v6/members/1/ratings']);
      expect(ratings.single.movieId, 550);
    });
  });

  test('RatingDto and CheckResult parse direct v6 success responses', () {
    final rating = RatingDto.fromJson({
      'ratingId': 3,
      'movieId': 13,
      'score': 3,
      'comment': null,
      'createdAt': '2026-11-01T19:00:27.956Z',
      'updatedAt': '2026-11-01T19:00:27.956Z',
    });
    expect(rating.ratingId, 3);
    expect(rating.movieId, 13);
    expect(rating.score, 3);
    expect(rating.comment, isNull);
    expect(rating.createdAt, DateTime.utc(2026, 11, 1, 19, 0, 27, 956));

    expect(CheckResult.fromJson({'available': false}).available, isFalse);
  });
}

/// 실제 네트워크 대신 요청 경로를 기록하고 정해진 JSON을 돌려주는 Dio Adapter입니다.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.body);

  final String body;
  final paths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.uri.path);
    return ResponseBody.fromBytes(
      utf8.encode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
