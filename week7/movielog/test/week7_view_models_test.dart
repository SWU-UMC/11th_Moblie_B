import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/view_models/load_status.dart';
import 'package:movielog/view_models/movie_detail_view_model.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';
import 'package:movielog/view_models/submit_status.dart';

import 'support/fake_movie_log_services.dart';
import 'support/fake_tmdb_movie_service.dart';

const _request = CreateMemberRequest(
  email: 'zero@example.com',
  password: 'Password1!',
  nickname: '제로',
);

/// 중복 확인 둘 다 통과한 상태
Future<SignUpViewModel> _checkedSignUp(FakeSignUpService service) async {
  final viewModel = SignUpViewModel(service);
  viewModel.onNicknameChanged('제로');
  viewModel.onEmailChanged('zero@example.com');
  await viewModel.checkNickname('제로');
  await viewModel.checkEmail('zero@example.com');
  return viewModel;
}

void main() {
  group('SignUpViewModel.submit', () {
    test('성공하면 createdMemberId에 응답 memberId', () async {
      final service = FakeSignUpService()..nextMemberId = 7;
      final viewModel = await _checkedSignUp(service);

      final submitting = viewModel.submit(_request);
      expect(viewModel.submitStatus, SubmitStatus.submitting);
      await submitting;

      expect(viewModel.submitStatus, SubmitStatus.success);
      expect(viewModel.createdMemberId, 7);
      expect(service.signUpCalls.single.toJson()['nickname'], '제로');
    });

    test('제출 중 다시 눌러도 요청은 한 번', () async {
      final service = FakeSignUpService()..signUpGate = Completer();
      final viewModel = await _checkedSignUp(service);
      final first = viewModel.submit(_request);
      await viewModel.submit(_request);
      service.signUpGate!.complete();
      await first;
      expect(service.signUpCalls, hasLength(1));
    });

    test('비밀번호 400 → passwordErrorText, 비밀번호 바꾸면 지워짐', () async {
      final service = FakeSignUpService()
        ..signUpError = fakeCommonError(
          '/v6/members',
          400,
          '비밀번호는 대문자/소문자/숫자/특수문자를 포함한 8자 이상이어야 합니다.',
        );
      final viewModel = await _checkedSignUp(service);
      await viewModel.submit(_request);

      expect(viewModel.submitStatus, SubmitStatus.error);
      expect(viewModel.passwordErrorText, contains('비밀번호'));
      expect(viewModel.snackbarMessage, isNull);

      viewModel.onPasswordChanged();
      expect(viewModel.passwordErrorText, isNull);
    });

    test('비밀번호 아닌 400은 Snackbar로', () async {
      final service = FakeSignUpService()
        ..signUpError = fakeCommonError(
          '/v6/members',
          400,
          '올바른 이메일 형식이 아닙니다.',
        );
      final viewModel = await _checkedSignUp(service);
      await viewModel.submit(_request);
      expect(viewModel.passwordErrorText, isNull);
      expect(viewModel.snackbarMessage, '올바른 이메일 형식이 아닙니다.');
    });

    test('최종 409(이메일) → Snackbar + 이메일 칸 중복으로 되돌려 가입 불가', () async {
      final service = FakeSignUpService()
        ..signUpError = fakeCommonError('/v6/members', 409, '이미 사용 중인 이메일입니다.');
      final viewModel = await _checkedSignUp(service);
      expect(viewModel.isDuplicateCheckDone, isTrue);

      await viewModel.submit(_request);
      expect(viewModel.snackbarMessage, '이미 사용 중인 이메일입니다.');
      expect(viewModel.emailCheckStatus, CheckStatus.duplicated);
      expect(viewModel.nicknameCheckStatus, CheckStatus.available);
      expect(viewModel.isDuplicateCheckDone, isFalse);

      // 이메일 바꾸면 이전 서버 오류도 같이 무효화
      viewModel.onEmailChanged('zero2@example.com');
      expect(viewModel.snackbarMessage, isNull);
      expect(viewModel.emailCheckStatus, CheckStatus.idle);
    });

    test('성공 응답에 memberId 없으면 가입 완료로 안 봄', () async {
      final service = FakeSignUpService()..omitMemberId = true;
      final viewModel = await _checkedSignUp(service);
      await viewModel.submit(_request);
      expect(viewModel.submitStatus, SubmitStatus.error);
      expect(viewModel.createdMemberId, isNull);
      expect(viewModel.snackbarMessage, contains('가입 결과를 확인하지 못했습니다'));
    });
  });

  group('MovieDetailViewModel.createRating', () {
    MovieDetailViewModel detail(
      FakeRatingApiService ratings, {
      int? memberId,
    }) => MovieDetailViewModel(
      FakeTmdbMovieService(),
      ratings,
      movieId: 3,
      memberId: memberId,
      movie: fakeMovie(3),
    );

    test('memberId 없으면 요청 안 하고 회원가입 안내', () async {
      final ratings = FakeRatingApiService();
      final viewModel = detail(ratings);
      expect(viewModel.canRate, isFalse);
      await viewModel.createRating(score: 4);
      expect(ratings.createCalls, isEmpty);
      expect(viewModel.submitMessage, '먼저 회원가입을 완료해 주세요.');
    });

    test('TMDB id를 movieId로, 학습용 memberId path로 등록', () async {
      final ratings = FakeRatingApiService();
      final viewModel = detail(ratings, memberId: 4);
      await viewModel.createRating(score: 5, comment: '최고');
      final (memberId, body) = ratings.createCalls.single;
      expect(memberId, 4);
      expect(body, {'movieId': 3, 'score': 5, 'comment': '최고'});
      expect(viewModel.submitStatus, SubmitStatus.success);
      expect(viewModel.myScore, 5);
    });

    test('409 중복 등록은 서버 문구로 실패', () async {
      final ratings = FakeRatingApiService()
        ..writeError = fakeCommonError('/r', 409, '이미 이 영화에 평점을 남기셨습니다.');
      final viewModel = detail(ratings, memberId: 4);
      await viewModel.createRating(score: 5);
      expect(viewModel.submitStatus, SubmitStatus.error);
      expect(viewModel.submitMessage, '이미 이 영화에 평점을 남기셨습니다.');
    });

    test('응답 오기 전에 화면 나가면 결과 반영 안 함', () async {
      final ratings = FakeRatingApiService()..writeGate = Completer();
      final viewModel = detail(ratings, memberId: 4);
      final creating = viewModel.createRating(score: 5);
      viewModel.dispose();
      ratings.writeGate!.complete();
      await creating;
      expect(viewModel.submitStatus, SubmitStatus.submitting);
    });
  });

  group('MyRatingsViewModel 수정·삭제', () {
    Future<(MyRatingsViewModel, FakeRatingApiService)> loaded() async {
      final ratings = FakeRatingApiService();
      final viewModel = MyRatingsViewModel(ratings, FakeTmdbMovieService(), 4);
      await viewModel.load();
      return (viewModel, ratings);
    }

    test('수정 성공 → PATCH 후 다시 조회해서 목록 갱신', () async {
      final (viewModel, ratings) = await loaded();
      final callsBefore = ratings.calls;
      await viewModel.updateRating(ratingId: 2, score: 2, comment: '바뀜');

      final (memberId, ratingId, body) = ratings.updateCalls.single;
      expect((memberId, ratingId), (4, 2));
      expect(body, {'score': 2, 'comment': '바뀜'});
      expect(ratings.calls, callsBefore + 1);
      final updated = viewModel.ratings.firstWhere(
        (e) => e.rating.ratingId == 2,
      );
      expect(updated.rating.score, 2);
      expect(updated.rating.comment, '바뀜');
    });

    test('수정 실패(400)는 SubmitFailure로 던지고 다시 조회 안 함', () async {
      final (viewModel, ratings) = await loaded();
      ratings.writeError = fakeCommonError('/r', 400, '별점은 5점 이하여야 합니다.');
      final callsBefore = ratings.calls;
      await expectLater(
        viewModel.updateRating(ratingId: 2, score: 5),
        throwsA(
          isA<SubmitFailure>().having(
            (e) => e.message,
            'message',
            '별점은 5점 이하여야 합니다.',
          ),
        ),
      );
      expect(ratings.calls, callsBefore);
    });

    test('403·404는 화면 목록이 어긋난 거라 다시 조회', () async {
      final (viewModel, ratings) = await loaded();
      ratings.writeError = fakeCommonError(
        '/r',
        403,
        '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.',
      );
      final callsBefore = ratings.calls;
      await expectLater(
        viewModel.deleteRating(2),
        throwsA(isA<SubmitFailure>()),
      );
      expect(ratings.calls, callsBefore + 1);
    });

    test('저장은 성공했는데 재조회만 실패 → 쓰기 실패로 안 던지고 refreshWarning', () async {
      final (viewModel, ratings) = await loaded();
      ratings.failFetchAfterWrite = true;

      await viewModel.updateRating(ratingId: 2, score: 1); // 예외 없음
      expect(ratings.updateCalls, hasLength(1));
      expect(viewModel.status, LoadStatus.error);
      expect(viewModel.refreshWarning, MyRatingsViewModel.refreshFailedMessage);

      // 조회만 다시 → 성공하면 경고 사라짐
      ratings
        ..failFetchAfterWrite = false
        ..failStatus = null;
      await viewModel.load();
      expect(viewModel.status, LoadStatus.success);
      expect(viewModel.refreshWarning, isNull);
    });

    test('마지막 평점 삭제하면 Empty', () async {
      final ratings = FakeRatingApiService(ratings: [fakeRating(1, 3)]);
      final viewModel = MyRatingsViewModel(ratings, FakeTmdbMovieService(), 4);
      await viewModel.load();
      await viewModel.deleteRating(1);
      expect(ratings.deleteCalls, [1]);
      expect(viewModel.status, LoadStatus.empty);
    });

    test('다중 삭제: 일부 실패하면 성공한 것만 사라지고 실패한 건 선택 유지', () async {
      final (viewModel, ratings) = await loaded();
      ratings.failDeleteIds = {2};
      viewModel
        ..startEditing()
        ..toggleSelected(1)
        ..toggleSelected(2);

      final deleting = viewModel.deleteSelectedRatings();
      expect(viewModel.isDeletingSelected, isTrue);
      final failed = await deleting;

      expect(failed, 1);
      expect(viewModel.isDeletingSelected, isFalse);
      expect(viewModel.selectedRatingIds, {2});
      expect(viewModel.isEditing, isTrue);
      expect(viewModel.ratings.map((e) => e.rating.ratingId), [3, 2]);
    });

    test('다중 삭제 전부 성공하면 편집 모드 끝', () async {
      final (viewModel, _) = await loaded();
      viewModel
        ..startEditing()
        ..toggleSelected(1)
        ..toggleSelected(3);
      expect(await viewModel.deleteSelectedRatings(), 0);
      expect(viewModel.isEditing, isFalse);
      expect(viewModel.selectedRatingIds, isEmpty);
      expect(viewModel.ratings.map((e) => e.rating.ratingId), [2]);
    });

    test('편집 취소하면 선택 해제', () async {
      final (viewModel, _) = await loaded();
      viewModel
        ..startEditing()
        ..toggleSelected(1)
        ..cancelEditing();
      expect(viewModel.isEditing, isFalse);
      expect(viewModel.selectedRatingIds, isEmpty);
    });
  });
}
