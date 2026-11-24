import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/router/app_routes.dart';
import 'package:movielog/screens/my_ratings_screen.dart';
import 'package:movielog/widgets/movie/rating_dialog.dart';
import 'package:movielog/widgets/movielog_button.dart';
import 'package:movielog/widgets/my_ratings/delete_rating_dialog.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_movie_log_services.dart';
import 'support/app_harness.dart';

/// 로그인된 상태로 location에서 시작
Future<TestApp> _pumpApp(
  WidgetTester tester,
  String location, {
  FakeRatingApiService? ratingService,
}) => pumpApp(tester, location: location, ratingApi: ratingService);

/// 이번 세션에서 3편 등록한 상태로 "내가 등록한 평점" 열기
/// 화면 순서(최근 위): 영화 13(3점, 후기 없음) / 영화 2(4점) / 영화 3(5점)
/// ratingId: 영화 3 → 100, 영화 2 → 101, 영화 13 → 102
Future<TestApp> _pumpMyRatings(
  WidgetTester tester, {
  FakeRatingApiService? ratingService,
  List<(int, int, String?)> seed = const [
    (3, 5, '최고의 영화!'),
    (2, 4, '다시 봐도 좋다'),
    (13, 3, null),
  ],
}) async {
  final ratings = ratingService ?? FakeRatingApiService();
  final app = await _pumpApp(tester, AppRoutes.home, ratingService: ratings);
  // 등록 준비 중엔 테스트용 지연·실패 잠깐 끔
  final (gate, error) = (ratings.writeGate, ratings.writeError);
  ratings
    ..writeGate = null
    ..writeError = null;
  for (final (movieId, score, comment) in seed) {
    app.sessionRatings.add(
      await ratings.createRating(
        CreateRatingRequest(movieId: movieId, score: score, comment: comment),
      ),
    );
  }
  ratings
    ..createCalls.clear()
    ..writeGate = gate
    ..writeError = error;
  app.router.push(AppRoutes.myRatings);
  await tester.pumpAndSettle();
  return app;
}

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
      // 9주차 Challenge 문구로 바뀜
      expect(find.text('평점을 저장했습니다.'), findsOneWidget);
      // memberId 없이 TMDB id만
      expect(ratings.createCalls.single, {
        'movieId': 3,
        'score': 4,
        'comment': '좋았다',
      });
      // 등록 result로 바로 반영
      expect(find.text('내 평점 4점 등록됨'), findsOneWidget);
    });

    testWidgets('실패(400): Dialog 유지, 입력 그대로, 서버 문구, 다시 누를 수 있음', (
      tester,
    ) async {
      final ratings = FakeRatingApiService()
        ..writeError = fakeCodeError(
          '/v8/ratings',
          400,
          'COMMON400',
          '별점은 5점 이하여야 합니다.',
        );
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
      expect(find.text('별점은 5점 이하여야 합니다.'), findsOneWidget);
      expect(_inDialog(find.text('두 번째')), findsOneWidget);
      final confirm = _button(tester, _dialogButton('확인'));
      expect(confirm.isLoading, isFalse);
      expect(confirm.onPressed, isNotNull);
    });

    testWidgets('9주차: RATING409_1은 Dialog 닫고 Snackbar, 로그인 유지', (tester) async {
      final ratings = FakeRatingApiService()
        ..writeError = fakeCodeError(
          '/v8/ratings',
          409,
          'RATING409_1',
          '이미 이 영화에 평점을 남기셨습니다.',
        );
      await _pumpApp(
        tester,
        AppRoutes.movieDetailOf(3),
        ratingService: ratings,
      );
      await tester.tap(find.text('평점 남기기'));
      await tester.pumpAndSettle();
      await _tapStar(tester, 5);
      await tester.tap(_dialogButton('확인'));
      await tester.pumpAndSettle();

      expect(find.byType(RatingDialog), findsNothing);
      expect(find.text('이미 이 영화에 평점을 남겼어요.'), findsOneWidget);
      expect(find.text('평점 남기기'), findsOneWidget); // 상세 그대로
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
      await _pumpMyRatings(tester);
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
      await _pumpMyRatings(tester);
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
    testWidgets('카드마다 수정·삭제, 수정은 기존 별점·코멘트가 채워진 Dialog → 저장 후 재조회', (
      tester,
    ) async {
      final ratings = FakeRatingApiService();
      await _pumpMyRatings(tester, ratingService: ratings);
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

      final (ratingId, body) = ratings.updateCalls.single;
      expect(ratingId, 101);
      expect(body, {'score': 2, 'comment': '다시 봐도 좋다'}); // 코멘트 유지해서 보냄
      expect(find.text('별점 2 / 5'), findsOneWidget);
      expect(find.text('평점을 수정했습니다.'), findsOneWidget);
    });

    testWidgets('코멘트 없는 평점 수정은 빈 칸으로 시작', (tester) async {
      await _pumpMyRatings(tester);
      await tester.tap(find.widgetWithText(MovieLogButton, '수정').first);
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(_inDialog(find.byType(TextField)));
      expect(field.controller!.text, isEmpty);
    });

    testWidgets('삭제: 취소하면 요청 없음, 삭제하면 목록 갱신, 마지막이면 Empty', (tester) async {
      final ratings = FakeRatingApiService();
      await _pumpMyRatings(
        tester,
        ratingService: ratings,
        seed: const [(3, 5, '하나')],
      );

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
      expect(ratings.deleteCalls, [100]);
      expect(find.text('이번 로그인에서 등록한 평점이 없어요.'), findsOneWidget);
    });

    testWidgets('삭제 실패(403): Dialog에 문구, 로그인 유지', (tester) async {
      final ratings = FakeRatingApiService()..failDeleteIds = {102};
      final app = await _pumpMyRatings(tester, ratingService: ratings);

      await tester.tap(find.widgetWithText(MovieLogButton, '삭제').first);
      await tester.pumpAndSettle();
      await tester.tap(_dialogButton('삭제'));
      await tester.pumpAndSettle();

      expect(
        _inDialog(find.text('본인이 작성한 평점만 수정하거나 삭제할 수 있어요.')),
        findsOneWidget,
      );
      expect(find.byType(MyRatingsScreen), findsOneWidget);
      expect(app.auth.isSignedIn, isTrue);
    });

    testWidgets('이미 없는 평점(404)은 문구 보여주고 목록에서도 뺌', (tester) async {
      final ratings = FakeRatingApiService();
      await _pumpMyRatings(tester, ratingService: ratings);
      ratings.server.remove(102);

      await tester.tap(find.widgetWithText(MovieLogButton, '삭제').first);
      await tester.pumpAndSettle();
      await tester.tap(_dialogButton('삭제'));
      await tester.pumpAndSettle();
      expect(_inDialog(find.text('이미 삭제됐거나 없는 평점이에요.')), findsOneWidget);
      await tester.tap(_dialogButton('취소'));
      await tester.pumpAndSettle();
      expect(find.byType(RatingCard), findsNWidgets(2));
    });

    testWidgets('수정 중 401: 세션 정리 → 로그인 화면 + 만료 Snackbar', (tester) async {
      final ratings = FakeRatingApiService();
      final app = await _pumpMyRatings(tester, ratingService: ratings);
      ratings.writeError = fakeExpiredError('/v8/ratings/102');

      await tester.tap(find.widgetWithText(MovieLogButton, '수정').first);
      await tester.pumpAndSettle();
      await _tapStar(tester, 1);
      await tester.tap(_dialogButton('확인'));
      await tester.pumpAndSettle();

      expect(app.location, AppRoutes.login);
      expect(find.text('로그인이 만료됐어요. 다시 로그인해 주세요.'), findsOneWidget);
      expect(app.tokenStorage.token, isNull);
    });
  });

  group('Challenge: 편집 → 다중 삭제', () {
    testWidgets('편집: 체크박스·선택 개수·취소, 1개 이상 선택해야 삭제 버튼 활성화', (tester) async {
      await _pumpMyRatings(tester);

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
      await _pumpMyRatings(tester, ratingService: ratings);
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
      expect(ratings.deleteCalls, [102, 100]);
      expect(find.byType(RatingCard), findsOneWidget);
      expect(find.text('선택한 평점을 삭제했습니다.'), findsOneWidget);
    });

    testWidgets('일부 실패: 성공한 것만 사라지고 Snackbar, 실패한 건 선택 유지', (tester) async {
      final ratings = FakeRatingApiService()..failDeleteIds = {101};
      await _pumpMyRatings(tester, ratingService: ratings);
      await tester.tap(find.text('편집'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).at(0)); // ratingId 102
      await tester.tap(find.byType(Checkbox).at(1)); // ratingId 101 (실패)
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
