import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../view_models/signup_view_model.dart';
import '../widgets/movielog_app_bar.dart';
import '../widgets/movielog_button.dart';

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

  /// 형식 검사를 통과하고, 닉네임·이메일 모두 "사용 가능"을 확인해야 가입할 수 있습니다.
  bool _canSubmit(SignUpViewModel viewModel) =>
      _validateNickname(_nicknameController.text) == null &&
      _validateEmail(_emailController.text) == null &&
      _validatePassword(_passwordController.text) == null &&
      viewModel.nicknameCheckStatus == CheckStatus.available &&
      viewModel.emailCheckStatus == CheckStatus.available &&
      _agreedToTerms;

  void _handleSubmit() {
    if (!_canSubmit(context.read<SignUpViewModel>())) return;
    setState(() {
      _nicknameTouched = true;
      _emailTouched = true;
      _passwordTouched = true;
    });
    FocusScope.of(context).unfocus();
    final isValid = _formKey.currentState?.validate() ?? false;
    if (isValid && _agreedToTerms) {
      // API 없이 화면 내부 상태만 사용합니다. go로 이동해 회원가입 화면을 스택에서 제거합니다.
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final viewModel = context.watch<SignUpViewModel>();
    // 글자 크기 설정에 따라 달라지는 중복 확인 버튼 너비입니다.
    final checkButtonWidth = MovieLogButton.contentWidth(context, '중복 확인');
    final nicknameStatus = viewModel.nicknameCheckStatus;
    final emailStatus = viewModel.emailCheckStatus;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: MovieLogAppBar(
          title: '회원가입',
          titleColor: colors.primary,
          // 회원가입 화면에서는 뒤로 가기를 허용하지 않으므로 뒤로가기 버튼을 두지 않습니다.
          automaticallyImplyLeading: false,
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
                    onChanged: (value) {
                      setState(() => _nicknameTouched = true);
                      viewModel.onNicknameChanged(value);
                    },
                    onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    serverErrorText: viewModel.nicknameErrorText,
                    confirmed: nicknameStatus == CheckStatus.available,
                    statusText: switch (nicknameStatus) {
                      CheckStatus.checking => '닉네임 사용 여부를 확인 중입니다.',
                      CheckStatus.available => '사용 가능한 닉네임입니다.',
                      _ => null,
                    },
                    statusColor: nicknameStatus == CheckStatus.available
                        ? AppColors.success
                        : AppColors.info,
                    // 입력창 옆 보조 버튼이므로 width를 주지 않아 내용 기반 크기를 씁니다.
                    trailingWidth: checkButtonWidth,
                    trailing: MovieLogButton(
                      label: '중복 확인',
                      isLoading: nicknameStatus == CheckStatus.checking,
                      onPressed:
                          viewModel.canCheckNickname &&
                              _validateNickname(_nicknameController.text) ==
                                  null
                          ? () => viewModel.checkNickname(
                              _nicknameController.text,
                            )
                          : null,
                    ),
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
                    onChanged: (value) {
                      setState(() => _emailTouched = true);
                      viewModel.onEmailChanged(value);
                    },
                    onFieldSubmitted: (_) =>
                        FocusScope.of(context).requestFocus(_passwordFocusNode),
                    serverErrorText: viewModel.emailErrorText,
                    confirmed: emailStatus == CheckStatus.available,
                    statusText: switch (emailStatus) {
                      CheckStatus.checking => '이메일 사용 여부를 확인 중입니다.',
                      CheckStatus.available => '사용 가능한 이메일입니다.',
                      _ => null,
                    },
                    statusColor: emailStatus == CheckStatus.available
                        ? AppColors.success
                        : AppColors.info,
                    trailingWidth: checkButtonWidth,
                    trailing: MovieLogButton(
                      label: '중복 확인',
                      isLoading: emailStatus == CheckStatus.checking,
                      onPressed:
                          viewModel.canCheckEmail &&
                              _validateEmail(_emailController.text) == null
                          ? () => viewModel.checkEmail(_emailController.text)
                          : null,
                    ),
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
                  // Form 맨 아래 버튼은 화면 전체 너비를 사용합니다.
                  MovieLogButton(
                    label: '가입하기',
                    width: double.infinity,
                    height: 48,
                    onPressed: _canSubmit(viewModel) ? _handleSubmit : null,
                  ),
                ],
              ),
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
    this.serverErrorText,
    this.confirmed,
    this.statusText,
    this.statusColor,
    this.trailing,
    this.trailingWidth,
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

  /// 서버 중복 확인 결과 에러 문구입니다. 형식 검사 에러가 있으면 그쪽이 먼저 보입니다.
  final String? serverErrorText;

  /// 서버 확인까지 끝났는지 여부입니다. null이면 형식 검사 결과로만 체크 표시를 정합니다.
  final bool? confirmed;

  /// 에러가 없을 때 입력창 아래에 보여줄 상태 문구입니다. (확인 중, 사용 가능)
  final String? statusText;
  final Color? statusColor;

  /// 입력창 바깥 오른쪽에 둘 위젯입니다. (중복 확인 버튼)
  final Widget? trailing;

  /// [trailing]이 차지할 너비입니다. 옆에 둘 자리가 있는지 판단할 때 씁니다.
  final double? trailingWidth;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final isValid = validator(controller.text) == null;
    final showError = (touched && !isValid) || serverErrorText != null;
    // 체크 표시는 입력창 내부에만 두어 옆 버튼과 겹치지 않게 합니다.
    final showCheck =
        !showError &&
        touched &&
        isValid &&
        controller.text.isNotEmpty &&
        (confirmed ?? true);
    final borderColor = showError ? colors.error : colors.outlineVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.titleSmall),
        const SizedBox(height: 8),
        _withTrailing(
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
              errorText: serverErrorText,
              helperText: showError ? null : statusText,
              helperStyle: textTheme.bodySmall?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
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
        ),
      ],
    );
  }

  /// 입력창이 이 너비보다 좁아지면 버튼을 입력창 아래로 내립니다.
  static const _minFieldWidth = 160.0;

  /// 입력창과 버튼을 Row의 별도 형제로 두고 8px 간격을 줍니다.
  /// 위쪽을 맞춰 두어, 입력창 아래에 문구가 생겨도 버튼 위치는 그대로입니다.
  /// 화면이 좁거나 글자가 커서 입력창이 너무 좁아지면 버튼을 아래로 내립니다.
  Widget _withTrailing(Widget field) {
    final trailing = this.trailing;
    if (trailing == null) return field;
    return LayoutBuilder(
      builder: (context, constraints) {
        final fieldWidth = constraints.maxWidth - 8 - (trailingWidth ?? 0);
        if (fieldWidth >= _minFieldWidth) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: field),
              const SizedBox(width: 8),
              trailing,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            field,
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: trailing),
          ],
        );
      },
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
          // 글자가 커져도 넘치지 않고 줄바꿈되도록 남은 너비 안에 둡니다.
          const Flexible(child: Text('필수 약관에 동의합니다')),
        ],
      ),
    );
  }
}
