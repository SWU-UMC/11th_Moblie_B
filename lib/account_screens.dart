// 대화에서 완성한 2주차 입력 검증 구조를 재사용한 화면입니다.
// 실제 인증/API 없이 시작 → 회원가입 → 홈의 이동만 연결합니다.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/logos/movielog_logo.png', width: 160),
                const SizedBox(height: 24),
                Text('MovieLog', style: theme.textTheme.headlineLarge),
                const SizedBox(height: 12),
                Text('나만의 영화 기록을 시작해보세요.', style: theme.textTheme.bodyLarge),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.go('/register'),
                    child: const Text('시작하기'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final formKey = GlobalKey<FormState>();
  final nicknameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final emailNode = FocusNode();
  final passwordNode = FocusNode();
  final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  bool agreedToTerms = false;
  bool nicknameEdited = false;
  bool emailEdited = false;
  bool passwordEdited = false;

  String? validateNickname(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '닉네임을 입력해주세요.';
    if (text.length < 2) return '닉네임은 2자 이상이어야 합니다.';
    return null;
  }

  String? validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '이메일을 입력해주세요.';
    if (!emailPattern.hasMatch(text)) return '올바른 이메일 형식이 아닙니다.';
    return null;
  }

  String? validatePassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return '비밀번호를 입력해주세요.';
    if (text.length < 8) return '비밀번호는 8자 이상이어야 합니다.';
    return null;
  }

  void submitForm() {
    setState(() {
      nicknameEdited = true;
      emailEdited = true;
      passwordEdited = true;
    });
    final valid = formKey.currentState?.validate() ?? false;
    if (!valid || !agreedToTerms) return;
    FocusScope.of(context).unfocus();
    // 3주차 변경점: 검증 완료 후 홈으로 이동합니다.
    context.go('/home');
  }

  @override
  void dispose() {
    nicknameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    emailNode.dispose();
    passwordNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nicknameValid = validateNickname(nicknameController.text) == null;
    final emailValid = validateEmail(emailController.text) == null;
    final passwordValid = validatePassword(passwordController.text) == null;
    final canSubmit =
        nicknameValid && emailValid && passwordValid && agreedToTerms;
    final theme = Theme.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 3주차는 회원가입 화면에 뒤로가기 버튼을 두지 않습니다.
                            Text(
                              '회원가입',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineLarge,
                            ),
                            const SizedBox(height: 32),
                            Text(
                              '환영합니다!\n간단한 정보만 입력하고 시작해보세요.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 40),
                            SignUpInputField(
                              label: '닉네임',
                              hintText: '닉네임을 입력해주세요',
                              controller: nicknameController,
                              edited: nicknameEdited,
                              isValid: nicknameValid,
                              validator: validateNickname,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) =>
                                  setState(() => nicknameEdited = true),
                              onFieldSubmitted: (_) => emailNode.requestFocus(),
                            ),
                            const SizedBox(height: 20),
                            SignUpInputField(
                              label: '이메일',
                              hintText: '이메일 주소를 입력해주세요',
                              controller: emailController,
                              focusNode: emailNode,
                              edited: emailEdited,
                              isValid: emailValid,
                              validator: validateEmail,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) =>
                                  setState(() => emailEdited = true),
                              onFieldSubmitted: (_) =>
                                  passwordNode.requestFocus(),
                            ),
                            const SizedBox(height: 20),
                            SignUpInputField(
                              label: '비밀번호',
                              hintText: '비밀번호를 입력해주세요',
                              controller: passwordController,
                              focusNode: passwordNode,
                              edited: passwordEdited,
                              isValid: passwordValid,
                              validator: validatePassword,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              onChanged: (_) =>
                                  setState(() => passwordEdited = true),
                              onFieldSubmitted: (_) =>
                                  FocusScope.of(context).unfocus(),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Checkbox(
                                    value: agreedToTerms,
                                    onChanged: (value) => setState(
                                      () => agreedToTerms = value ?? false,
                                    ),
                                  ),
                                  const Expanded(child: Text('필수 약관에 동의합니다')),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: canSubmit ? submitForm : null,
                                child: const Text('가입하기'),
                              ),
                              const SizedBox(height: 24),
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  const Text('이미 계정이 있나요?'),
                                  TextButton(
                                    onPressed: null,
                                    child: const Text('로그인'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class SignUpInputField extends StatelessWidget {
  const SignUpInputField({
    super.key,
    required this.label,
    required this.hintText,
    required this.controller,
    required this.edited,
    required this.isValid,
    required this.validator,
    required this.onChanged,
    required this.onFieldSubmitted,
    required this.textInputAction,
    this.focusNode,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
  });
  final String label;
  final String hintText;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool edited;
  final bool isValid;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?) validator;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = edited && !isValid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          autocorrect: false,
          enableSuggestions: !obscureText,
          style: theme.textTheme.bodyLarge,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            hintText: hintText,
            fillColor: hasError ? theme.colorScheme.errorContainer : null,
            suffixIcon: hasError
                ? Icon(Icons.error_outline, color: theme.colorScheme.error)
                : isValid
                ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                : null,
          ),
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
        ),
      ],
    );
  }
}
