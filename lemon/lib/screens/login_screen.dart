import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../view_models/auth_view_model.dart';
import '../widgets/movielog_app_bar.dart';
import '../widgets/movielog_button.dart';

/// 로그인 화면입니다.
///
/// 버튼은 `AuthViewModel.login()`만 부르고 직접 `/home`으로 이동하지 않습니다.
/// 성공하면 status가 signedIn이 되고 Router가 홈으로 보냅니다.
/// 세션 만료로 이동해 왔다면 Snackbar로 이유를 한 번 알려줍니다.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.initialEmail});

  /// 회원가입 직후처럼 이메일을 미리 채워 둘 때 씁니다. 비밀번호는 채우지 않습니다.
  final String? initialEmail;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail ?? '');
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  late final AuthViewModel _auth;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthViewModel>();
    // 화면이 열려 있는 중에 만료되는 경우와, 이미 만료된 상태로 열리는 경우를 모두 처리합니다.
    _auth.addListener(_showSessionExpired);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showSessionExpired());
  }

  /// go('/login', extra: email)로 다시 들어오면 go_router가 기존 State를 재사용할 수 있습니다.
  /// 새 이메일이 오면 입력칸을 바꾸고, null이거나 같으면 사용자가 입력한 값을 유지합니다.
  @override
  void didUpdateWidget(covariant LoginScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final email = widget.initialEmail;
    if (email != null && email != oldWidget.initialEmail) {
      _email.text = email;
    }
  }

  void _showSessionExpired() {
    if (!mounted || !_auth.sessionExpired) return;
    _auth.consumeSessionExpired();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('로그인이 만료됐어요. 다시 로그인해 주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  void dispose() {
    _auth.removeListener(_showSessionExpired);
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _submit() {
    final auth = context.read<AuthViewModel>();
    if (auth.status == AuthStatus.authenticating ||
        auth.storageCleanupInProgress) {
      return;
    }
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    auth.login(_email.text.trim(), _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final auth = context.watch<AuthViewModel>();
    final loading = auth.status == AuthStatus.authenticating;
    // 토큰 삭제가 실패했다면 지우기를 끝낼 때까지 새 로그인을 막습니다.
    final enabled =
        !loading && !auth.storageCleanupInProgress && !auth.tokenCleanupFailed;
    final message = auth.message;

    return Scaffold(
      appBar: MovieLogAppBar(
        title: '로그인',
        titleColor: colors.primary,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: SvgPicture.asset(
                    'assets/logos/movielog_logo.svg',
                    width: 64,
                    height: 64,
                    semanticsLabel: 'MovieLog 로고',
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'MovieLog에 로그인',
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall,
                ),
                const SizedBox(height: 40),
                _LabeledField(
                  label: '이메일',
                  child: TextFormField(
                    controller: _email,
                    enabled: enabled,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: _decoration(context, '이메일을 입력해 주세요'),
                    onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? '이메일을 입력해 주세요.'
                        : null,
                  ),
                ),
                const SizedBox(height: 20),
                _LabeledField(
                  label: '비밀번호',
                  child: TextFormField(
                    controller: _password,
                    focusNode: _passwordFocus,
                    enabled: enabled,
                    obscureText: true, // 화면에도 비밀번호 원문을 보여주지 않습니다.
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    decoration: _decoration(context, '비밀번호를 입력해 주세요'),
                    onFieldSubmitted: (_) => _submit(),
                    validator: (value) =>
                        (value?.isEmpty ?? true) ? '비밀번호를 입력해 주세요.' : null,
                  ),
                ),
                // 로그인 실패(AUTH401_1)·저장 실패·통신 실패는 각자 다른 문구로 Form 아래에 보여줍니다.
                if (auth.tokenCleanupFailed)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            message ?? '저장된 로그인 정보를 지우지 못했어요.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colors.error,
                            ),
                          ),
                        ),
                        MovieLogButton(
                          label: '다시 지우기',
                          isLoading: auth.storageCleanupInProgress,
                          onPressed: auth.retryTokenCleanup,
                        ),
                      ],
                    ),
                  )
                else if (message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      message,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 48),
                MovieLogButton(
                  label: '로그인',
                  width: double.infinity,
                  height: 48,
                  isLoading: loading,
                  onPressed: enabled ? _submit : null,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '계정이 없나요?',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    TextButton(
                      onPressed: enabled ? () => context.push('/signup') : null,
                      child: const Text('회원가입'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static InputDecoration _decoration(BuildContext context, String hint) {
    final colors = Theme.of(context).colorScheme;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color),
    );
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: colors.surfaceContainerLowest,
      enabledBorder: border(colors.outlineVariant),
      focusedBorder: border(colors.primary),
      disabledBorder: border(colors.outlineVariant),
    );
  }
}

/// 입력칸 위에 이름표를 두는 Figma 로그인·프로필 수정 Form 모양입니다.
class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
