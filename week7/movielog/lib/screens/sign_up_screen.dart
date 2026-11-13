import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/create_member_request.dart';
import '../router/app_routes.dart';
import '../theme/app_colors.dart';
import '../utils/sign_up_validators.dart';
import '../view_models/learning_member_session.dart';
import '../view_models/sign_up_view_model.dart';
import '../view_models/submit_status.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movielog_button.dart';
import '../widgets/sign_up/login_prompt.dart';
import '../widgets/sign_up/movielog_text_form_field.dart';
import '../widgets/sign_up/sign_up_header.dart';
import '../widgets/sign_up/terms_agreement.dart';

/// W2 회원가입 + 6주차 중복 확인 + 7주차 가입 POST
/// 형식 검사는 validator, 중복 확인·가입 요청은 SignUpViewModel
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  /// 이 너비보다 넓으면 Form 가운데 정렬 + 최대 너비 제한
  static const wideLayoutBreakpoint = 700.0;
  static const maxFormWidth = 560.0;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  // controller, focusNode는 State에서 만들고 dispose
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _agreedToTerms = false;
  bool _obscurePassword = true;

  /// 가입하기 눌렀는지 (전체 검증 했는지)
  bool _submitted = false;

  /// 한 번이라도 입력한 칸 (입력 전엔 에러 표시 X)
  final _touched = <TextEditingController>{};

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nicknameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  /// 형식 OK + 중복 확인 둘 다 통과 + 약관 동의 + 제출 중 아님
  bool _canSubmit(SignUpViewModel viewModel) =>
      SignUpValidators.nickname(_nicknameController.text) == null &&
      SignUpValidators.email(_emailController.text) == null &&
      SignUpValidators.password(_passwordController.text) == null &&
      viewModel.isDuplicateCheckDone &&
      _agreedToTerms &&
      !viewModel.isSubmitting;

  FieldStatus _statusOf(
    TextEditingController controller,
    FormFieldValidator<String> validator,
  ) {
    if (validator(controller.text) == null) return FieldStatus.valid;
    final showError = _submitted || _touched.contains(controller);
    return showError ? FieldStatus.error : FieldStatus.idle;
  }

  /// 서버 결과까지 반영한 입력창 상태
  FieldStatus _checkedStatusOf(
    TextEditingController controller,
    FormFieldValidator<String> validator,
    CheckStatus checkStatus,
    String? serverErrorText,
  ) {
    if (serverErrorText != null) return FieldStatus.error;
    final formatStatus = _statusOf(controller, validator);
    if (formatStatus != FieldStatus.valid) return formatStatus;
    // 중복 확인까지 통과해야 체크 표시
    return checkStatus == CheckStatus.available
        ? FieldStatus.valid
        : FieldStatus.idle;
  }

  (String?, Color?) _checkHelper(
    String fieldName,
    CheckStatus checkStatus,
    bool formatValid,
  ) => switch (checkStatus) {
    CheckStatus.available => ('사용 가능한 $fieldName입니다.', AppColors.success),
    CheckStatus.checking => ('$fieldName 사용 가능 여부를 확인 중입니다.', AppColors.violet),
    CheckStatus.idle when formatValid => ('중복 확인을 눌러 주세요.', AppColors.hint),
    _ => (null, null),
  };

  void _onFieldChanged(TextEditingController controller) {
    setState(() => _touched.add(controller));
  }

  Future<void> _submit(SignUpViewModel viewModel) async {
    setState(() => _submitted = true);
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || !viewModel.isDuplicateCheckDone || !_agreedToTerms) return;

    FocusScope.of(context).unfocus();
    final nickname = _nicknameController.text.trim();
    await viewModel.submit(
      CreateMemberRequest(
        email: _emailController.text,
        password: _passwordController.text,
        nickname: _nicknameController.text,
      ),
    );
    if (!mounted) return;

    final memberId = viewModel.createdMemberId;
    if (viewModel.submitStatus == SubmitStatus.success && memberId != null) {
      // 받은 memberId를 세션에 저장 → 평점 등록·조회에 사용
      context.read<LearningMemberSession>().setMember(
        memberId,
        nickname: nickname,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$nickname님, 가입을 환영해요! (memberId $memberId)')),
      );
      // go로 이동해서 뒤로가기로 회원가입에 못 돌아오게 함
      context.go(AppRoutes.movies);
      return;
    }
    // 비밀번호 400은 입력칸 errorText로, 나머지(409 등)는 Snackbar로
    final message = viewModel.snackbarMessage;
    if (message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = context.select<SignUpViewModel, bool>(
      (viewModel) => viewModel.isSubmitting,
    );
    // 가입 요청 중엔 뒤로가기·스와이프 백 막음 (끝나면 다시 풀림)
    return PopScope(
      canPop: !isSubmitting,
      child: Scaffold(
        // 회원가입 화면은 뒤로가기 버튼 없음
        appBar: const CommonAppBar(title: '회원가입', centerTitle: true),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide =
                  constraints.maxWidth >= SignUpScreen.wideLayoutBreakpoint;

              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isWide
                        ? SignUpScreen.maxFormWidth
                        : double.infinity,
                  ),
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                    child: ConstrainedBox(
                      // 내용 짧으면 약관/버튼을 아래에 붙임
                      // 키보드 올라오면 스크롤됨
                      constraints: BoxConstraints(
                        minHeight: (constraints.maxHeight - 48).clamp(
                          0,
                          double.infinity,
                        ),
                      ),
                      child: _buildForm(),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    final viewModel = context.watch<SignUpViewModel>();
    final isSubmitting = viewModel.isSubmitting;
    final nicknameText = _nicknameController.text;
    final emailText = _emailController.text;
    final nicknameFormatValid = SignUpValidators.nickname(nicknameText) == null;
    final emailFormatValid = SignUpValidators.email(emailText) == null;
    final (nicknameHelper, nicknameHelperColor) = _checkHelper(
      '닉네임',
      viewModel.nicknameCheckStatus,
      nicknameFormatValid,
    );
    final (emailHelper, emailHelperColor) = _checkHelper(
      '이메일',
      viewModel.emailCheckStatus,
      emailFormatValid,
    );

    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SignUpHeader(),
              const SizedBox(height: 32),
              MovieLogTextFormField(
                label: '닉네임',
                hintText: '닉네임을 입력해주세요',
                controller: _nicknameController,
                focusNode: _nicknameFocusNode,
                enabled: !isSubmitting,
                validator: SignUpValidators.nickname,
                status: _checkedStatusOf(
                  _nicknameController,
                  SignUpValidators.nickname,
                  viewModel.nicknameCheckStatus,
                  viewModel.nicknameErrorText,
                ),
                forceErrorText: viewModel.nicknameErrorText,
                helperText: nicknameHelper,
                helperColor: nicknameHelperColor,
                textInputAction: TextInputAction.next,
                onChanged: (value) {
                  _onFieldChanged(_nicknameController);
                  viewModel.onNicknameChanged(value);
                },
                onFieldSubmitted: (_) => _emailFocusNode.requestFocus(),
                // width 안 줌 → 글자 길이만큼
                action: MovieLogButton(
                  label: '중복 확인',
                  isLoading:
                      viewModel.nicknameCheckStatus == CheckStatus.checking,
                  onPressed:
                      viewModel.canCheckNickname &&
                          nicknameFormatValid &&
                          !isSubmitting
                      ? () => viewModel.checkNickname(nicknameText)
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              MovieLogTextFormField(
                label: '이메일',
                hintText: '이메일 주소를 입력해주세요',
                controller: _emailController,
                focusNode: _emailFocusNode,
                enabled: !isSubmitting,
                validator: SignUpValidators.email,
                status: _checkedStatusOf(
                  _emailController,
                  SignUpValidators.email,
                  viewModel.emailCheckStatus,
                  viewModel.emailErrorText,
                ),
                forceErrorText: viewModel.emailErrorText,
                helperText: emailHelper,
                helperColor: emailHelperColor,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                onChanged: (value) {
                  _onFieldChanged(_emailController);
                  viewModel.onEmailChanged(value);
                },
                onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                action: MovieLogButton(
                  label: '중복 확인',
                  isLoading: viewModel.emailCheckStatus == CheckStatus.checking,
                  onPressed:
                      viewModel.canCheckEmail &&
                          emailFormatValid &&
                          !isSubmitting
                      ? () => viewModel.checkEmail(emailText)
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              MovieLogTextFormField(
                label: '비밀번호',
                hintText: '비밀번호를 입력해주세요',
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                enabled: !isSubmitting,
                validator: SignUpValidators.password,
                status: viewModel.passwordErrorText != null
                    ? FieldStatus.error
                    : _statusOf(_passwordController, SignUpValidators.password),
                // 로컬 validator 통과해도 서버가 거부하면 계속 에러로 보임
                forceErrorText: viewModel.passwordErrorText,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onChanged: (_) {
                  _onFieldChanged(_passwordController);
                  viewModel.onPasswordChanged();
                },
                onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                trailing: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.hint,
                  ),
                  tooltip: _obscurePassword ? '비밀번호 보기' : '비밀번호 숨기기',
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              TermsAgreement(
                agreed: _agreedToTerms,
                onChanged: (value) => setState(() => _agreedToTerms = value),
              ),
              const SizedBox(height: 16),
              // 부모 너비 꽉 채움
              MovieLogButton(
                label: '가입하기',
                width: double.infinity,
                height: 56,
                isLoading: isSubmitting,
                onPressed: _canSubmit(viewModel)
                    ? () => _submit(viewModel)
                    : null,
              ),
              const SizedBox(height: 24),
              const LoginPrompt(),
            ],
          ),
        ],
      ),
    );
  }
}
