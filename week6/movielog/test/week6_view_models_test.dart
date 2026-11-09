import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/view_models/load_status.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';

import 'support/fake_movie_log_services.dart';
import 'support/fake_tmdb_movie_service.dart';

void main() {
  group('SignUpViewModel', () {
    test('확인 전 → 통신 중 → 사용 가능', () async {
      final viewModel = SignUpViewModel(FakeMemberCheckService());
      viewModel.onNicknameChanged('제로');
      expect(viewModel.nicknameCheckStatus, CheckStatus.idle);

      final checking = viewModel.checkNickname('제로');
      expect(viewModel.nicknameCheckStatus, CheckStatus.checking);
      expect(viewModel.canCheckNickname, isFalse);

      await checking;
      expect(viewModel.nicknameCheckStatus, CheckStatus.available);
      expect(viewModel.nicknameErrorText, isNull);
    });

    test('중복이면 에러 문구와 함께 버튼이 비활성화된다', () async {
      final viewModel = SignUpViewModel(FakeMemberCheckService());
      viewModel.onNicknameChanged('무비러버');
      await viewModel.checkNickname('무비러버');

      expect(viewModel.nicknameCheckStatus, CheckStatus.duplicated);
      expect(viewModel.nicknameErrorText, '이미 사용 중인 닉네임입니다.');
      expect(viewModel.canCheckNickname, isFalse);
    });

    test('입력을 바꾸면 이전 결과가 무효화되고, 중복이었던 값을 다시 쓰면 묻지 않고 바로 에러', () async {
      final service = FakeMemberCheckService();
      final viewModel = SignUpViewModel(service);
      viewModel.onNicknameChanged('무비러버');
      await viewModel.checkNickname('무비러버');

      viewModel.onNicknameChanged('무비러버2');
      expect(viewModel.nicknameCheckStatus, CheckStatus.idle);
      expect(viewModel.nicknameErrorText, isNull);
      expect(viewModel.canCheckNickname, isTrue);

      viewModel.onNicknameChanged(' 무비러버 '); // 앞뒤 공백은 같은 값
      expect(viewModel.nicknameCheckStatus, CheckStatus.duplicated);
      expect(viewModel.nicknameErrorText, '이미 사용 중인 닉네임입니다.');
      expect(viewModel.canCheckNickname, isFalse);
      expect(service.nicknameCalls, ['무비러버']); // 다시 요청 X
    });

    test('통신 실패는 중복과 다른 상태·문구', () async {
      final service = FakeMemberCheckService()..fail = true;
      final viewModel = SignUpViewModel(service);
      viewModel.onEmailChanged('zero@example.com');
      await viewModel.checkEmail('zero@example.com');

      expect(viewModel.emailCheckStatus, CheckStatus.error);
      expect(viewModel.emailErrorText, SignUpViewModel.checkFailedMessage);
      expect(viewModel.canCheckEmail, isTrue); // 다시 시도 가능
    });

    test('응답을 기다리는 중 입력을 바꾸면 늦게 온 응답은 무시한다', () async {
      final service = FakeMemberCheckService()..gate = Completer();
      final viewModel = SignUpViewModel(service);
      viewModel.onNicknameChanged('무비러버');
      final checking = viewModel.checkNickname('무비러버');

      viewModel.onNicknameChanged('새닉네임');
      service.gate!.complete();
      await checking;

      expect(viewModel.nicknameCheckStatus, CheckStatus.idle);
      expect(viewModel.nicknameErrorText, isNull);
    });

    test('닉네임과 이메일 결과는 서로 영향을 주지 않는다', () async {
      final viewModel = SignUpViewModel(FakeMemberCheckService());
      viewModel.onNicknameChanged('무비러버');
      viewModel.onEmailChanged('zero@example.com');
      await viewModel.checkNickname('무비러버');
      await viewModel.checkEmail('zero@example.com');

      expect(viewModel.nicknameCheckStatus, CheckStatus.duplicated);
      expect(viewModel.emailCheckStatus, CheckStatus.available);
      expect(viewModel.isDuplicateCheckDone, isFalse);
    });
  });

  group('MyRatingsViewModel', () {
    test('평점과 TMDB 영화 정보를 묶어 Success', () async {
      final viewModel = MyRatingsViewModel(
        FakeRatingApiService(),
        FakeTmdbMovieService(),
        sampleMemberId,
      );
      await viewModel.load();

      expect(viewModel.status, LoadStatus.success);
      expect(viewModel.ratings.map((e) => e.movie?.title), [
        '영화 13',
        '영화 2',
        '영화 3',
      ]);
      expect(viewModel.message, isNull);
    });

    test('빈 배열은 Error가 아니라 Empty', () async {
      final viewModel = MyRatingsViewModel(
        FakeRatingApiService(ratings: []),
        FakeTmdbMovieService(),
        3,
      );
      await viewModel.load();
      expect(viewModel.status, LoadStatus.empty);
    });

    test('없는 회원(404)·형식 오류(400)는 Error와 서로 다른 문구', () async {
      for (final (status, message) in [
        (404, '존재하지 않는 회원입니다.'),
        (400, 'memberId 형식을 다시 확인해 주세요.'),
      ]) {
        final viewModel = MyRatingsViewModel(
          FakeRatingApiService()..failStatus = status,
          FakeTmdbMovieService(),
          sampleMemberId,
        );
        await viewModel.load();
        expect(viewModel.status, LoadStatus.error);
        expect(viewModel.message, message);
      }
    });

    test('TMDB에서 영화를 못 찾아도(404) 평점은 남기고 영화만 비운다', () async {
      final viewModel = MyRatingsViewModel(
        FakeRatingApiService(ratings: [fakeRating(1, 999), fakeRating(2, 3)]),
        FakeTmdbMovieService(),
        sampleMemberId,
      );
      await viewModel.load();

      expect(viewModel.status, LoadStatus.success);
      expect(viewModel.ratings, hasLength(2));
      expect(viewModel.ratings.first.movie, isNull);
      expect(viewModel.ratings.first.rating.movieId, 999);
      expect(viewModel.message, contains('일부 영화 정보를 가져오지 못해'));
    });

    test('TMDB 통신 실패도 평점 목록을 지우지 않고, 같은 movieId는 한 번만 묻는다', () async {
      final tmdb = FakeTmdbMovieService();
      final viewModel = MyRatingsViewModel(
        FakeRatingApiService(
          ratings: [fakeRating(1, 3), fakeRating(2, 3), fakeRating(3, 5)],
        ),
        tmdb,
        sampleMemberId,
      );
      await viewModel.load();
      expect(tmdb.detailCalls, [3, 5]);

      tmdb.failDetail = true;
      await viewModel.load(); // 캐시된 영화는 다시 안 물어봄
      expect(tmdb.detailCalls, [3, 5]);
      expect(viewModel.ratings, hasLength(3));
    });

    test('불러오는 중 화면이 사라지면(dispose) 늦게 온 응답을 무시한다', () async {
      final ratings = FakeRatingApiService()..gate = Completer();
      final viewModel = MyRatingsViewModel(
        ratings,
        FakeTmdbMovieService(),
        sampleMemberId,
      );
      final loading = viewModel.load();
      viewModel.dispose();
      ratings.gate!.complete();
      await loading;
      expect(viewModel.ratings, isEmpty);
    });
  });
}
