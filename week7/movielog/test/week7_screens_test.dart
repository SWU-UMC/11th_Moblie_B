import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:movielog/data/movie_preferences.dart';
import 'package:movielog/main.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/router/app_routes.dart';
import 'package:movielog/screens/my_ratings_screen.dart';
import 'package:movielog/utils/sign_up_validators.dart';
import 'package:movielog/view_models/learning_member_session.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/widgets/movie/rating_dialog.dart';
import 'package:movielog/widgets/movielog_button.dart';
import 'package:movielog/widgets/my_ratings/delete_rating_dialog.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_movie_log_services.dart';
import 'support/fake_tmdb_movie_service.dart';

Future<GoRouter> _pumpApp(
  WidgetTester tester,
  String location, {
  FakeSignUpService? signUpService,
  FakeRatingApiService? ratingService,
  LearningMemberSession? session,
}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = AppRouter.createRouter(
    initialLocation: location,
    preferences: MoviePreferences(),
  );
  await tester.pumpWidget(
    MovieLogApp(
      router: router,
      movieService: FakeTmdbMovieService(),
      signUpService: signUpService ?? FakeSignUpService(),
      ratingApiService: ratingService ?? FakeRatingApiService(),
      memberSession: session ?? LearningMemberSession(memberId: 4),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

Finder _inDialog(Finder matching) =>
    find.descendant(of: find.byType(Dialog), matching: matching);

MovieLogButton _button(WidgetTester tester, Finder finder) =>
    tester.widget<MovieLogButton>(finder);

/// Dialog 흰 배경 (Dialog 위젯 자체는 화면 전체 크기)
Finder _dialogSurface() => find
    .descendant(of: find.byType(Dialog), matching: find.byType(Material))
    .first;

Finder _dialogButton(String label) =>
    _inDialog(find.widgetWithText(MovieLogButton, label));

/// Dialog 별점에서 n번째 별 탭 (1~5)
Future<void> _tapStar(WidgetTester tester, int n) async {
  final stars = _inDialog(
    find.byWidgetPredicate(
      (w) => w is Icon && (w.icon == Icons.star || w.icon == Icons.star_border),
    ),
  );
  await tester.tap(stars.at(n - 1));
  await tester.pump();
}

bool _canPop(WidgetTester tester, Finder scope) =>
    tester.widget<PopScope>(scope).canPop;

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('회원가입 제출', () {
    Future<void> fillAndCheck(WidgetTester tester) async {
      await tester.enterText(
        find.widgetWithText(TextFormField, '닉네임을 입력해주세요'),
        '제로',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '이메일 주소를 입력해주세요'),
        'zero@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '비밀번호를 입력해주세요'),
        'Password1!',
      );
      await tester.pump();
      final checks = find.widgetWithText(MovieLogButton, '중복 확인');
      await tester.tap(checks.at(0));
      await tester.tap(checks.at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('필수 약관에 동의합니다'));
      await tester.pump();
    }

    testWidgets('성공: memberId를 세션에 저장하고 Snackbar 후 영화 목록으로', (tester) async {
      final session = LearningMemberSession();
      final router = await _pumpApp(
        tester,
        AppRoutes.register,
        signUpService: FakeSignUpService()..nextMemberId = 77,
        session: session,
      );
      await fillAndCheck(tester);
      await tester.tap(find.text('가입하기'));
      await tester.pumpAndSettle();

      expect(session.memberId, 77);
      expect(find.text('제로님, 가입을 환영해요! (memberId 77)'), findsOneWidget);
      expect(_location(router), AppRoutes.movies);
    });

    testWidgets('제출 중: 가입하기 로딩, 입력·뒤로가기 막힘, 끝나면 풀림', (tester) async {
      final service = FakeSignUpService()
        ..signUpGate = Completer()
        ..signUpError = fakeCommonError('/v6/members', 409, '이미 사용 중인 닉네임입니다.');
      await _pumpApp(
        tester,
        AppRoutes.register,
        signUpService: service,
        session: LearningMemberSession(),
      );
      await fillAndCheck(tester);
      await tester.tap(find.text('가입하기'));
      await tester.pump();

      final submit = find.widgetWithText(MovieLogButton, '가입하기');
      expect(_button(tester, submit).isLoading, isTrue);
      expect(_canPop(tester, find.byType(PopScope).first), isFalse);
      final nickname = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, '제로'),
      );
      expect(nickname.enabled, isFalse);

      service.signUpGate!.complete();
      await tester.pumpAndSettle();
      expect(_canPop(tester, find.byType(PopScope).first), isTrue);
      expect(service.signUpCalls, hasLength(1));
    });

    testWidgets('최종 409: Snackbar로 알리고 닉네임 칸이 중복 에러, 가입하기 비활성화', (
      tester,
    ) async {
      final service = FakeSignUpService()
        ..signUpError = fakeCommonError('/v6/members', 409, '이미 사용 중인 닉네임입니다.');
      await _pumpApp(
        tester,
        AppRoutes.register,
        signUpService: service,
        session: LearningMemberSession(),
      );
      await fillAndCheck(tester);
      await tester.tap(find.text('가입하기'));
      await tester.pumpAndSettle();

      // Snackbar 1개 + 닉네임 칸 에러 1개
      expect(find.text('이미 사용 중인 닉네임입니다.'), findsNWidgets(2));
      final submit = find.widgetWithText(MovieLogButton, '가입하기');
      expect(_button(tester, submit).onPressed, isNull);
    });

    testWidgets('비밀번호 400: 비밀번호 칸 errorText, 비밀번호 고치면 사라짐', (tester) async {
      final service = FakeSignUpService()
        ..signUpError = fakeCommonError(
          '/v6/members',
          400,
          SignUpValidators.passwordRuleMessage,
        );
      await _pumpApp(
        tester,
        AppRoutes.register,
        signUpService: service,
        session: LearningMemberSession(),
      );
      await fillAndCheck(tester);
      await tester.tap(find.text('가입하기'));
      await tester.pumpAndSettle();

      expect(find.text(SignUpValidators.passwordRuleMessage), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password1!'),
        'Password2!',
      );
      await tester.pumpAndSettle();
      expect(find.text(SignUpValidators.passwordRuleMessage), findsNothing);
    });
  });

  group('영화 상세 평점 등록', () {
    testWidgets('Dialog: 별점 골라야 확인 활성화, 코멘트 입력, 저장 중 이탈 막힘 → 성공 Snackbar', (
      tester,
    ) async {
      final ratings = FakeRatingApiService()..writeGate = Completer();
      await _pumpApp(
        tester,
        AppRoutes.movieDetailOf(3),
        ratingService: ratings,
      );
      await tester.tap(find.text('평점 남기기'));
      await tester.pumpAndSettle();

      expect(find.text('평점을 남겨주세요'), findsOneWidget);
      await tester.enterText(_inDialog(find.byType(TextField)), '  좋았다  ');
      await tester.pump();
      // 코멘트만으론 확인 안 됨
      expect(_button(tester, _dialogButton('확인')).onPressed, isNull);

      await _tapStar(tester, 4);
      expect(_button(tester, _dialogButton('확인')).onPressed, isNotNull);

      await tester.tap(_dialogButton('확인'));
      await tester.pump();
      expect(_button(tester, _dialogButton('확인')).isLoading, isTrue);
      expect(_button(tester, _dialogButton('취소')).onPressed, isNull);
      expect(
        _canPop(
          tester,
          find.descendant(
            of: find.byType(RatingDialog),
            matching: find.byType(PopScope),
          ),
        ),
        isFalse,
      );

      // 바깥 탭해도 안 닫힘 (barrierDismissible false)
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      expect(find.byType(RatingDialog), findsOneWidget);

      ratings.writeGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(RatingDialog), findsNothing);
      expect(
        find.text('평점을 등록했습니다. 마이페이지의 "내가 등록한 평점"에서 확인할 수 있습니다.'),
        findsOneWidget,
      );
      final (memberId, body) = ratings.createCalls.single;
      expect(memberId, 4);
      expect(body, {'movieId': 3, 'score': 4, 'comment': '좋았다'});
    });

    testWidgets('실패(409): Dialog 유지, 입력 그대로, 서버 문구, 다시 누를 수 있음', (
      tester,
    ) async {
      final ratings = FakeRatingApiService()
        ..writeError = fakeCommonError('/r', 409, '이미 이 영화에 평점을 남기셨습니다.');
      await _pumpApp(
        tester,
        AppRoutes.movieDetailOf(3),
        ratingService: ratings,
      );
      await tester.tap(find.text('평점 남기기'));
      await tester.pumpAndSettle();
      await _tapStar(tester, 5);
      await tester.enterText(_inDialog(find.byType(TextField)), '두 번째');
      await tester.tap(_dialogButton('확인'));
      await tester.pumpAndSettle();

      expect(find.byType(RatingDialog), findsOneWidget);
      expect(find.text('이미 이 영화에 평점을 남기셨습니다.'), findsOneWidget);
      expect(_inDialog(find.text('두 번째')), findsOneWidget);
      final confirm = _button(tester, _dialogButton('확인'));
      expect(confirm.isLoading, isFalse);
      expect(confirm.onPressed, isNotNull);
    });

    testWidgets('취소하면 요청 없음', (tester) async {
      final ratings = FakeRatingApiService();
      await _pumpApp(
        tester,
        AppRoutes.movieDetailOf(3),
        ratingService: ratings,
      );
      await tester.tap(find.text('평점 남기기'));
      await tester.pumpAndSettle();
      await _tapStar(tester, 3);
      await tester.tap(_dialogButton('취소'));
      await tester.pumpAndSettle();
      expect(find.byType(RatingDialog), findsNothing);
      expect(ratings.createCalls, isEmpty);
    });
  });

  group('Figma 크기', () {
    testWidgets('390 폭에서 카드 350x156, 수정·삭제 63x35, 편집 카드 350x128', (
      tester,
    ) async {
      await _pumpApp(tester, AppRoutes.myRatings);
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byType(RatingCard).first),
        const Size(350, 156),
      );
      expect(
        tester.getSize(find.widgetWithText(MovieLogButton, '수정').first),
        const Size(63, 35),
      );
      expect(tester.getTopLeft(find.byType(RatingCard).first).dx, 20);

      await tester.tap(find.text('편집'));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(SelectableRatingCard).first),
        const Size(350, 128),
      );
      expect(
        tester.getSize(find.widgetWithText(MovieLogButton, '선택한 0개 삭제')),
        const Size(342, 49),
      );
    });

    testWidgets('평점 Dialog 340 폭, 버튼 140x46 / 삭제 Dialog 328 폭, 버튼 134x44', (
      tester,
    ) async {
      await _pumpApp(tester, AppRoutes.myRatings);
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(MovieLogButton, '수정').first);
      await tester.pumpAndSettle();
      expect(tester.getSize(_dialogSurface()).width, 340);
      expect(tester.getSize(_dialogButton('확인')), const Size(140, 46));
      await tester.tap(_dialogButton('취소'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(MovieLogButton, '삭제').first);
      await tester.pumpAndSettle();
      expect(tester.getSize(_dialogSurface()).width, 328);
      expect(tester.getSize(_dialogButton('삭제')), const Size(134, 44));
    });
  });

  group('내가 등록한 평점 수정·삭제', () {
    testWidgets('memberId 없으면 회원가입 안내', (tester) async {
      await _pumpApp(
        tester,
        AppRoutes.myRatings,
        session: LearningMemberSession(),
      );
      expect(find.text('학습용 회원가입이 필요합니다.'), findsOneWidget);
    });

    testWidgets('카드마다 수정·삭제, 수정은 기존 별점·코멘트가 채워진 Dialog → 저장 후 재조회', (
      tester,
    ) async {
      final ratings = FakeRatingApiService();
      await _pumpApp(tester, AppRoutes.myRatings, ratingService: ratings);
      expect(find.widgetWithText(MovieLogButton, '수정'), findsNWidgets(3));
      expect(find.widgetWithText(MovieLogButton, '삭제'), findsNWidgets(3));

      // 두 번째 카드: ratingId 2, 별점 4, '다시 봐도 좋다'
      await tester.tap(find.widgetWithText(MovieLogButton, '수정').at(1));
      await tester.pumpAndSettle();
      expect(_inDialog(find.text('다시 봐도 좋다')), findsOneWidget);
      expect(_button(tester, _dialogButton('확인')).onPressed, isNotNull);

      await _tapStar(tester, 2);
      await tester.tap(_dialogButton('확인'));
      await tester.pumpAndSettle();

      final (_, ratingId, body) = ratings.updateCalls.single;
      expect(ratingId, 2);
      expect(body, {'score': 2, 'comment': '다시 봐도 좋다'}); // 코멘트 유지해서 보냄
      expect(find.text('별점 2 / 5'), findsOneWidget);
      expect(find.text('평점을 수정했습니다.'), findsOneWidget);
    });

    testWidgets('코멘트 없는 평점 수정은 빈 칸으로 시작', (tester) async {
      await _pumpApp(tester, AppRoutes.myRatings);
      await tester.tap(find.widgetWithText(MovieLogButton, '수정').first);
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(_inDialog(find.byType(TextField)));
      expect(field.controller!.text, isEmpty);
    });

    testWidgets('저장 성공 후 재조회만 실패하면 조회 재시도 안내', (tester) async {
      final ratings = FakeRatingApiService()..failFetchAfterWrite = true;
      await _pumpApp(tester, AppRoutes.myRatings, ratingService: ratings);
      await tester.tap(find.widgetWithText(MovieLogButton, '수정').first);
      await tester.pumpAndSettle();
      await _tapStar(tester, 5);
      await tester.tap(_dialogButton('확인'));
      await tester.pumpAndSettle();

      // 저장은 성공이라 Dialog는 닫힘
      expect(find.byType(RatingDialog), findsNothing);
      expect(
        find.text(MyRatingsViewModel.refreshFailedMessage),
        findsOneWidget,
      );

      ratings
        ..failFetchAfterWrite = false
        ..failStatus = null;
      await tester.tap(find.widgetWithText(MovieLogButton, '다시 시도'));
      await tester.pumpAndSettle();
      expect(find.byType(RatingCard), findsNWidgets(3));
      expect(ratings.updateCalls, hasLength(1)); // 저장은 다시 안 보냄
    });

    testWidgets('삭제: 취소하면 요청 없음, 삭제하면 목록 갱신, 마지막이면 Empty', (tester) async {
      final ratings = FakeRatingApiService(
        ratings: [fakeRating(1, 3, comment: '하나')],
      );
      await _pumpApp(tester, AppRoutes.myRatings, ratingService: ratings);

      await tester.tap(find.widgetWithText(MovieLogButton, '삭제'));
      await tester.pumpAndSettle();
      expect(find.text('평점을 삭제할까요?'), findsOneWidget);
      await tester.tap(_dialogButton('취소'));
      await tester.pumpAndSettle();
      expect(ratings.deleteCalls, isEmpty);

      ratings.writeGate = Completer();
      await tester.tap(find.widgetWithText(MovieLogButton, '삭제'));
      await tester.pumpAndSettle();
      await tester.tap(_dialogButton('삭제'));
      await tester.pump();
      // 단일 삭제는 끝날 때까지 Dialog 유지
      expect(find.byType(DeleteRatingDialog), findsOneWidget);
      expect(_button(tester, _dialogButton('삭제')).isLoading, isTrue);

      ratings.writeGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(DeleteRatingDialog), findsNothing);
      expect(ratings.deleteCalls, [1]);
      expect(find.text('아직 등록된 평점이 없어요.'), findsOneWidget);
    });

    testWidgets('삭제 실패(404): Dialog에 서버 문구, 목록 다시 조회', (tester) async {
      final ratings = FakeRatingApiService()..failDeleteIds = {3};
      await _pumpApp(tester, AppRoutes.myRatings, ratingService: ratings);
      final callsBefore = ratings.calls;

      await tester.tap(find.widgetWithText(MovieLogButton, '삭제').first);
      await tester.pumpAndSettle();
      await tester.tap(_dialogButton('삭제'));
      await tester.pumpAndSettle();

      expect(_inDialog(find.text('존재하지 않는 평점입니다.')), findsOneWidget);
      expect(ratings.calls, callsBefore + 1);
    });
  });

  group('Challenge: 편집 → 다중 삭제', () {
    testWidgets('편집: 체크박스·선택 개수·취소, 1개 이상 선택해야 삭제 버튼 활성화', (tester) async {
      await _pumpApp(tester, AppRoutes.myRatings);

      await tester.tap(find.text('편집'));
      await tester.pumpAndSettle();
      expect(find.byType(Checkbox), findsNWidgets(3));
      expect(find.widgetWithText(MovieLogButton, '수정'), findsNothing);
      expect(find.text('0개 선택됨'), findsOneWidget);
      final deleteButton = find.widgetWithText(MovieLogButton, '선택한 0개 삭제');
      expect(_button(tester, deleteButton).onPressed, isNull);

      await tester.tap(find.byType(Checkbox).at(0));
      await tester.tap(find.text('영화 2 · 별점 4')); // 카드 눌러도 선택
      await tester.pump();
      expect(find.text('2개 선택됨'), findsOneWidget);
      expect(
        _button(
          tester,
          find.widgetWithText(MovieLogButton, '선택한 2개 삭제'),
        ).onPressed,
        isNotNull,
      );

      await tester.tap(find.text('취소'));
      await tester.pump();
      expect(find.byType(Checkbox), findsNothing);
      expect(find.text('편집'), findsOneWidget);
    });

    testWidgets('확인 Dialog는 바로 닫히고, 삭제 중엔 오버레이·이탈 방지, 끝나면 갱신', (tester) async {
      final ratings = FakeRatingApiService()..writeGate = Completer();
      await _pumpApp(tester, AppRoutes.myRatings, ratingService: ratings);
      await tester.tap(find.text('편집'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).at(0));
      await tester.tap(find.byType(Checkbox).at(2));
      await tester.pump();

      await tester.tap(find.text('선택한 2개 삭제'));
      await tester.pumpAndSettle();
      expect(find.text('선택한 평점을 삭제할까요?'), findsOneWidget);
      await tester.tap(_dialogButton('삭제'));
      // Dialog 닫히는 애니메이션만 기다림 (인디케이터 계속 돌아서 settle 안 됨)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(DeleteRatingDialog), findsNothing);
      final overlay = find.descendant(
        of: find.byType(MyRatingsScreen),
        matching: find.byType(ModalBarrier),
      );
      expect(overlay, findsOneWidget);
      expect(_canPop(tester, find.byType(PopScope).first), isFalse);

      ratings.writeGate!.complete();
      await tester.pumpAndSettle();
      expect(overlay, findsNothing);
      expect(ratings.deleteCalls, [3, 1]);
      expect(find.byType(RatingCard), findsOneWidget);
      expect(find.text('선택한 평점을 삭제했습니다.'), findsOneWidget);
    });

    testWidgets('일부 실패: 성공한 것만 사라지고 Snackbar, 실패한 건 선택 유지', (tester) async {
      final ratings = FakeRatingApiService()..failDeleteIds = {2};
      await _pumpApp(tester, AppRoutes.myRatings, ratingService: ratings);
      await tester.tap(find.text('편집'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).at(0)); // ratingId 3
      await tester.tap(find.byType(Checkbox).at(1)); // ratingId 2 (실패)
      await tester.pump();
      await tester.tap(find.text('선택한 2개 삭제'));
      await tester.pumpAndSettle();
      await tester.tap(_dialogButton('삭제'));
      await tester.pumpAndSettle();

      expect(
        find.text('1개 항목을 삭제하지 못했습니다. 선택된 항목을 다시 확인해 주세요.'),
        findsOneWidget,
      );
      expect(find.byType(Checkbox), findsNWidgets(2));
      expect(find.text('1개 선택됨'), findsOneWidget);
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).at(0)).value,
        isTrue,
      );
    });
  });
}
