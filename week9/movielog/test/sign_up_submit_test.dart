import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';
import 'package:movielog/view_models/submit_status.dart';

import 'support/fake_movie_log_services.dart';

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
          '/v8/members',
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
          '/v8/members',
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
        ..signUpError = fakeCommonError('/v8/members', 409, '이미 사용 중인 이메일입니다.');
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
}
