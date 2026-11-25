import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/view_models/sign_up_view_model.dart';

import 'support/fake_movie_log_services.dart';

void main() {
  group('SignUpViewModel', () {
    test('확인 전 → 통신 중 → 사용 가능', () async {
      final viewModel = SignUpViewModel(FakeSignUpService());
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
      final viewModel = SignUpViewModel(FakeSignUpService());
      viewModel.onNicknameChanged('무비러버');
      await viewModel.checkNickname('무비러버');

      expect(viewModel.nicknameCheckStatus, CheckStatus.duplicated);
      expect(viewModel.nicknameErrorText, '이미 사용 중인 닉네임입니다.');
      expect(viewModel.canCheckNickname, isFalse);
    });

    test('입력을 바꾸면 이전 결과가 무효화되고, 중복이었던 값을 다시 쓰면 묻지 않고 바로 에러', () async {
      final service = FakeSignUpService();
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
      final service = FakeSignUpService()..fail = true;
      final viewModel = SignUpViewModel(service);
      viewModel.onEmailChanged('zero@example.com');
      await viewModel.checkEmail('zero@example.com');

      expect(viewModel.emailCheckStatus, CheckStatus.error);
      expect(viewModel.emailErrorText, SignUpViewModel.checkFailedMessage);
      expect(viewModel.canCheckEmail, isTrue); // 다시 시도 가능
    });

    test('응답을 기다리는 중 입력을 바꾸면 늦게 온 응답은 무시한다', () async {
      final service = FakeSignUpService()..gate = Completer();
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
      final viewModel = SignUpViewModel(FakeSignUpService());
      viewModel.onNicknameChanged('무비러버');
      viewModel.onEmailChanged('zero@example.com');
      await viewModel.checkNickname('무비러버');
      await viewModel.checkEmail('zero@example.com');

      expect(viewModel.nicknameCheckStatus, CheckStatus.duplicated);
      expect(viewModel.emailCheckStatus, CheckStatus.available);
      expect(viewModel.isDuplicateCheckDone, isFalse);
    });
  });
}
