import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../widgets/movielog_app_bar.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  bool _agreedToTerms = false;

  bool _nicknameTouched = false;
  bool _emailTouched = false;
  bool _passwordTouched = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  String? _validateNickname(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '닉네임을 입력해주세요.';
    if (text.length < 2) return '닉네임은 2자 이상이어야 합니다.';
    return null;
  }

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '이메일을 입력해주세요.';
    if (!_emailPattern.hasMatch(text)) return '올바른 이메일 형식이 아닙니다.';
    return null;
  }

  String? _validatePassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return '비밀번호를 입력해주세요.';
    if (text.length < 8) return '비밀번호는 8자 이상이어야 합니다.';
    return null;
  }

  bool get _canSubmit =>
      _validateNickname(_nicknameController.text) == null &&
      _validateEmail(_emailController.text) == null &&
      _validatePassword(_passwordController.text) == null &&
      _agreedToTerms;

  void _handleSubmit() {
    setState(() {
      _nicknameTouched = true;
      _emailTouched = true;
      _passwordTouched = true;
    });
    FocusScope.of(context).unfocus();
    final isValid = _formKey.currentState?.validate() ?? false;
    if (isValid && _agreedToTerms) {
      // API 없이 화면 내부 상태만 사용합니다. 실제 가입 처리는 이후 주차에서 연결합니다.
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: MovieLogAppBar(
        title: '회원가입',
        titleColor: colors.primary,
        leading: IconButton(
          onPressed: () {}, // Required Mission에서는 뒤로가기 네비게이션을 연결하지 않습니다.
          // SVG 아이콘만 있으면 스크린 리더가 버튼 이름을 읽을 수 없어, 기본 BackButton과 같은 문구를 붙입니다.
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: SvgPicture.asset(
            'assets/icons/arrow_back.svg',
            width: 24,
            height: 24,
            colorFilter: ColorFilter.mode(colors.onSurface, BlendMode.srcIn),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '환영합니다!\n간단한 정보만 입력하고 시작해보세요.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                _AuthTextField(
                  label: '닉네임',
                  hintText: '닉네임을 입력해주세요',
                  controller: _nicknameController,
                  validator: _validateNickname,
                  touched: _nicknameTouched,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() => _nicknameTouched = true),
                  onFieldSubmitted: (_) =>
                      FocusScope.of(context).nextFocus(),
                ),
                const SizedBox(height: 20),
                _AuthTextField(
                  label: '이메일',
                  hintText: '이메일 주소를 입력해주세요',
                  controller: _emailController,
                  validator: _validateEmail,
                  touched: _emailTouched,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() => _emailTouched = true),
                  onFieldSubmitted: (_) => FocusScope.of(
                    context,
                  ).requestFocus(_passwordFocusNode),
                ),
                const SizedBox(height: 20),
                _AuthTextField(
                  label: '비밀번호',
                  hintText: '비밀번호를 입력해주세요',
                  controller: _passwordController,
                  validator: _validatePassword,
                  touched: _passwordTouched,
                  obscureText: true,
                  focusNode: _passwordFocusNode,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() => _passwordTouched = true),
                  onFieldSubmitted: (_) => _handleSubmit(),
                ),
                const SizedBox(height: 24),
                _TermsCheckbox(
                  value: _agreedToTerms,
                  onChanged: (value) =>
                      setState(() => _agreedToTerms = value),
                ),
                const SizedBox(height: 16),
                _SubmitButton(
                  enabled: _canSubmit,
                  onPressed: _handleSubmit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthTextField extends StatelessWidget {
  const _AuthTextField({
    required this.label,
    required this.hintText,
    required this.controller,
    required this.validator,
    required this.touched,
    required this.onChanged,
    required this.onFieldSubmitted,
    this.textInputAction,
    this.keyboardType,
    this.obscureText = false,
    this.focusNode,
  });

  final String label;
  final String hintText;
  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final bool touched;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onFieldSubmitted;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final bool obscureText;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final isValid = validator(controller.text) == null;
    final showError = touched && !isValid;
    final showCheck = touched && isValid && controller.text.isNotEmpty;
    final borderColor = showError ? colors.error : colors.outlineVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.titleSmall),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: showError
                ? colors.errorContainer.withValues(alpha: 0.4)
                : colors.surfaceContainerHighest,
            suffixIcon: showError
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: SvgPicture.asset(
                      'assets/icons/error.svg',
                      width: 20,
                      height: 20,
                      colorFilter: ColorFilter.mode(
                        colors.error,
                        BlendMode.srcIn,
                      ),
                    ),
                  )
                : showCheck
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: SvgPicture.asset(
                      'assets/icons/check_circle.svg',
                      width: 20,
                      height: 20,
                      colorFilter: ColorFilter.mode(
                        colors.primary,
                        BlendMode.srcIn,
                      ),
                    ),
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: colors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: colors.error, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: value,
            activeColor: colors.primary,
            onChanged: (checked) => onChanged(checked ?? false),
          ),
          const Text('필수 약관에 동의합니다'),
        ],
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 48),
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          disabledBackgroundColor: colors.primary.withValues(alpha: 0.4),
          disabledForegroundColor: colors.onPrimary,
        ),
        child: const Text('가입하기'),
      ),
    );
  }
}
