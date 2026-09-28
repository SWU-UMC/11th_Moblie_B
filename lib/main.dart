import 'package:flutter/material.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MovieLogApp());
}

class MovieLogApp extends StatelessWidget {
  const MovieLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MovieLog',
      theme: AppTheme.lightTheme,
      home: const SignUpScreen(),
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

  // 아이콘 상태와 Form 검증에서 같은 규칙을 사용합니다.
  String? validateNickname(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return '닉네임을 입력해주세요.';
    }

    if (text.length < 2) {
      return '닉네임은 2자 이상이어야 합니다.';
    }

    return null;
  }

  String? validateEmail(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return '이메일을 입력해주세요.';
    }

    if (!emailPattern.hasMatch(text)) {
      return '올바른 이메일 형식이 아닙니다.';
    }

    return null;
  }

  String? validatePassword(String? value) {
    final text = value ?? '';

    if (text.isEmpty) {
      return '비밀번호를 입력해주세요.';
    }

    if (text.length < 8) {
      return '비밀번호는 8자 이상이어야 합니다.';
    }

    return null;
  }

  void submitForm() {
    setState(() {
      nicknameEdited = true;
      emailEdited = true;
      passwordEdited = true;
    });

    final isValid = formKey.currentState?.validate() ?? false;

    if (!isValid || !agreedToTerms) {
      return;
    }

    FocusScope.of(context).unfocus();

    // 실제 API 연결 없이 검증 완료만 알립니다.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('입력 정보가 확인되었습니다. 실제 가입은 진행하지 않습니다.'),
      ),
    );
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
    final nicknameValid =
        validateNickname(nicknameController.text) == null;
    final emailValid =
        validateEmail(emailController.text) == null;
    final passwordValid =
        validatePassword(passwordController.text) == null;

    final canSubmit =
        nicknameValid &&
        emailValid &&
        passwordValid &&
        agreedToTerms;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 상단과 입력 영역
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SignUpHeader(),

                            SignUpInputField(
                              label: '닉네임',
                              hintText: '닉네임을 입력해주세요',
                              controller: nicknameController,
                              edited: nicknameEdited,
                              isValid: nicknameValid,
                              validator: validateNickname,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) {
                                setState(() {
                                  nicknameEdited = true;
                                });
                              },
                              onFieldSubmitted: (_) {
                                emailNode.requestFocus();
                              },
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
                              onChanged: (_) {
                                setState(() {
                                  emailEdited = true;
                                });
                              },
                              onFieldSubmitted: (_) {
                                passwordNode.requestFocus();
                              },
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
                              onChanged: (_) {
                                setState(() {
                                  passwordEdited = true;
                                });
                              },
                              onFieldSubmitted: (_) {
                                FocusScope.of(context).unfocus();
                              },
                            ),
                          ],
                        ),

                        // 하단 영역: 입력창과 최소 32만큼 간격 유지
                        Padding(
                          padding: const EdgeInsets.only(top: 32),
                          child: SignUpFooter(
                            agreedToTerms: agreedToTerms,
                            onAgreementChanged: (value) {
                              setState(() {
                                agreedToTerms = value ?? false;
                              });
                            },
                            onSignUp: canSubmit ? submitForm : null,
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

// 1. 상단 제목과 환영 문구
class SignUpHeader extends StatelessWidget {
  const SignUpHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 56,
          child: Stack(
            children: [
              Center(
                child: Text(
                  '회원가입',
                  style: theme.textTheme.headlineLarge,
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: IconButton(
                  tooltip: '뒤로가기',
                  onPressed: () {
                    // 이전 화면이 있을 때만 돌아갑니다.
                    Navigator.of(context).maybePop();
                  },
                  icon: const Icon(Icons.arrow_back),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text(
          '환영합니다!\n간단한 정보만 입력하고 시작해보세요.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 48),
      ],
    );
  }
}

// 2. 제목과 입력창을 묶은 공통 위젯
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
  final void Function(String) onChanged;
  final void Function(String) onFieldSubmitted;

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
          style: theme.textTheme.bodyLarge,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          autocorrect: false,
          enableSuggestions: !obscureText,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            hintText: hintText,
            fillColor: hasError
                ? theme.colorScheme.errorContainer
                : null,
            suffixIcon: hasError
                ? Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.error,
                  )
                : isValid
                    ? Icon(
                        Icons.check_circle,
                        color: theme.colorScheme.primary,
                      )
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

// 3. 약관, 가입 버튼, 로그인 안내
class SignUpFooter extends StatelessWidget {
  const SignUpFooter({
    super.key,
    required this.agreedToTerms,
    required this.onAgreementChanged,
    required this.onSignUp,
  });

  final bool agreedToTerms;
  final void Function(bool?) onAgreementChanged;

  // null이면 가입 버튼이 비활성화됩니다.
  final VoidCallback? onSignUp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Checkbox(
              value: agreedToTerms,
              onChanged: onAgreementChanged,
            ),
            Expanded(
              child: Text(
                '필수 약관에 동의합니다',
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        ElevatedButton(
          onPressed: onSignUp,
          child: const Text('가입하기'),
        ),
        const SizedBox(height: 32),

        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '이미 계정이 있나요?',
              style: theme.textTheme.bodyMedium,
            ),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('로그인 화면은 이번 실습 범위에 포함되지 않습니다.'),
                  ),
                );
              },
              child: const Text(
                '로그인',
                style: TextStyle(
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}