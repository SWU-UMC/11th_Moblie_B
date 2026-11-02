import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/sign_up_validators.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/sign_up/login_prompt.dart';
import '../widgets/sign_up/movielog_text_form_field.dart';
import '../widgets/sign_up/sign_up_button.dart';
import '../widgets/sign_up/sign_up_header.dart';
import '../widgets/sign_up/terms_agreement.dart';

/// W2-01~04 회원가입 화면
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  /// 이 너비 이상이면 Form을 가운데에 두고 최대 너비를 제한합니다.
  static const wideLayoutBreakpoint = 700.0;
  static const maxFormWidth = 560.0;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controller와 FocusNode는 build가 아니라 State에서 한 번만 만들고 dispose합니다.
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _agreedToTerms = false;
  bool _obscurePassword = true;

  /// 가입하기를 눌러 전체 검증을 한 번 실행했는지
  bool _submitted = false;

  /// 사용자가 한 번이라도 입력한 칸 (그 전에는 오류 모양을 보여주지 않음)
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

  bool get _canSubmit =>
      SignUpValidators.nickname(_nicknameController.text) == null &&
      SignUpValidators.email(_emailController.text) == null &&
      SignUpValidators.password(_passwordController.text) == null &&
      _agreedToTerms;

  FieldStatus _statusOf(
    TextEditingController controller,
    FormFieldValidator<String> validator,
  ) {
    if (validator(controller.text) == null) return FieldStatus.valid;
    final showError = _submitted || _touched.contains(controller);
    return showError ? FieldStatus.error : FieldStatus.idle;
  }

  void _onFieldChanged(TextEditingController controller) {
    setState(() => _touched.add(controller));
  }

  void _submit() {
    setState(() => _submitted = true);
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || !_agreedToTerms) return;

    FocusScope.of(context).unfocus();
    // 2주차는 API 없이 화면 상태만 다룹니다.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_nicknameController.text.trim()}님, 가입을 환영해요!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '회원가입',
        centerTitle: true,
        onBack: () => Navigator.maybePop(context),
      ),
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
                    // 내용이 짧으면 약관·버튼을 화면 아래쪽에 두고,
                    // 키보드가 열려 공간이 줄면 스크롤됩니다.
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
    );
  }

  Widget _buildForm() {
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
                validator: SignUpValidators.nickname,
                status: _statusOf(
                  _nicknameController,
                  SignUpValidators.nickname,
                ),
                textInputAction: TextInputAction.next,
                onChanged: (_) => _onFieldChanged(_nicknameController),
                onFieldSubmitted: (_) => _emailFocusNode.requestFocus(),
              ),
              const SizedBox(height: 16),
              MovieLogTextFormField(
                label: '이메일',
                hintText: '이메일 주소를 입력해주세요',
                controller: _emailController,
                focusNode: _emailFocusNode,
                validator: SignUpValidators.email,
                status: _statusOf(_emailController, SignUpValidators.email),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                onChanged: (_) => _onFieldChanged(_emailController),
                onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
              ),
              const SizedBox(height: 16),
              MovieLogTextFormField(
                label: '비밀번호',
                hintText: '비밀번호를 입력해주세요',
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                validator: SignUpValidators.password,
                status: _statusOf(
                  _passwordController,
                  SignUpValidators.password,
                ),
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onChanged: (_) => _onFieldChanged(_passwordController),
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
              SignUpButton(onPressed: _canSubmit ? _submit : null),
              const SizedBox(height: 24),
              const LoginPrompt(),
            ],
          ),
        ],
      ),
    );
  }
}
