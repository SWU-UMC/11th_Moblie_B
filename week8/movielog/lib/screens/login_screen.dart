import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/movie_preferences.dart';
import '../router/app_routes.dart';
import '../theme/app_colors.dart';
import '../view_models/auth_view_model.dart';
import '../widgets/auth/auth_text_field.dart';
import '../widgets/movielog_button.dart';

/// Figma W8 로그인 글자 스타일 (Manrope, 줄 높이 125%)
abstract final class _LoginText {
  static const appBarTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: AppColors.violet,
  );
  static const title = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: AppColors.textPrimary,
  );
  static const label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.25,
    color: AppColors.textSecondary,
  );
  static const prompt = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.25,
    color: AppColors.textSecondary,
  );
  static const remember = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.25,
    color: AppColors.textPrimary,
  );
  static const link = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: AppColors.violet,
  );
  static const error = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.25,
    color: AppColors.error,
  );
}

/// W8-03 로그인 기본 / W8-04 요청 중 / W8-05 실패 / W8-CH01 이메일 저장
/// login()만 부르고 화면 이동은 안 함 → signedIn 되면 Router가 /home으로 보냄
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late final AuthViewModel _auth;
  MoviePreferences? _preferences;

  /// Challenge: 이메일 저장 체크
  bool _rememberEmail = false;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthViewModel>();
    // 로그인 화면 열려 있는 중에 만료되는 경우
    _auth.addListener(_showSessionExpired);
    // 이미 만료된 상태로 화면이 처음 열리는 경우
    WidgetsBinding.instance.addPostFrameCallback((_) => _showSessionExpired());
    _preferences = context.read<MoviePreferences?>();
    _loadSavedEmail();
  }

  Future<void> _loadSavedEmail() async {
    final preferences = _preferences;
    if (preferences == null) return;
    try {
      final saved = await preferences.readSavedEmail();
      if (!mounted || saved == null || saved.isEmpty) return;
      // 사용자가 이미 입력 시작했으면 덮어쓰지 않음
      if (_email.text.isEmpty) _email.text = saved;
      setState(() => _rememberEmail = true);
    } catch (_) {
      // 저장소 못 읽어도 로그인은 됨
    }
  }

  /// ViewModel은 "만료됐다"만 들고 있고 Snackbar는 화면이 띄움
  void _showSessionExpired() {
    if (!mounted || !_auth.sessionExpired) return;
    _auth.consumeSessionExpired(); // 먼저 꺼서 반복 표시 막음
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('로그인이 만료됐어요. 다시 로그인해 주세요.')));
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final email = _email.text.trim();
    await _syncSavedEmail(email);
    if (!mounted) return;
    await _auth.login(email, _password.text);
  }

  /// 체크했으면 이메일만 저장, 해제했으면 지움
  Future<void> _syncSavedEmail(String email) async {
    final preferences = _preferences;
    if (preferences == null) return;
    try {
      if (_rememberEmail) {
        await preferences.saveEmail(email);
      } else {
        await preferences.clearSavedEmail();
      }
    } catch (_) {
      // 이메일 저장 실패는 로그인 막을 이유 아님
    }
  }

  Future<void> _openRegister() async {
    // 가입 끝나면 이메일 들고 돌아옴 → 바로 채워 줌
    final email = await context.push<String>(AppRoutes.register);
    if (!mounted || email == null || email.isEmpty) return;
    _email.text = email;
    _password.clear();
  }

  @override
  void dispose() {
    _auth.removeListener(_showSessionExpired);
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final loading = auth.status == AuthStatus.authenticating;
    final enabled = !loading && !auth.storageCleanupInProgress;
    final message = auth.message;

    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      appBar: AppBar(
        toolbarHeight: 64,
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.screenBackground,
        surfaceTintColor: Colors.transparent,
        title: const Text('로그인', style: _LoginText.appBarTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Figma 세로 위치: 로고 132, 제목 227, 이메일 289/313, 비밀번호 386/410, 버튼 570
                const SizedBox(height: 68),
                Center(
                  child: SvgPicture.asset(
                    'assets/logos/movielog_logo.svg',
                    width: 84,
                    height: 84,
                    semanticsLabel: 'MovieLog 로고',
                  ),
                ),
                const SizedBox(height: 11),
                const Text(
                  'MovieLog에 로그인',
                  textAlign: TextAlign.center,
                  style: _LoginText.title,
                ),
                const SizedBox(height: 31),
                const Text('이메일', style: _LoginText.label),
                const SizedBox(height: 7),
                AuthTextField(
                  key: const Key('login-email'),
                  controller: _email,
                  enabled: enabled,
                  hintText: 'movie@example.com',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: (value) =>
                      (value?.trim().isEmpty ?? true) ? '이메일을 입력해 주세요.' : null,
                ),
                const SizedBox(height: 24),
                const Text('비밀번호', style: _LoginText.label),
                const SizedBox(height: 7),
                AuthTextField(
                  key: const Key('login-password'),
                  controller: _password,
                  // 로그인 실패면 비밀번호칸 테두리만 빨갛게 (문구는 아래 한 줄)
                  errorText: message,
                  hideErrorText: true,
                  enabled: enabled,
                  hintText: '비밀번호',
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => enabled ? _submit() : null,
                  validator: (value) =>
                      (value?.isEmpty ?? true) ? '비밀번호를 입력해 주세요.' : null,
                ),
                // 비밀번호칸 아래 ~ 버튼 사이 112 (Figma W8-05·CH01)
                // 실패 문구 +9, 이메일 저장 +35, 버튼은 항상 같은 자리
                const SizedBox(height: 9),
                SizedBox(
                  height: 15,
                  // 비밀번호 틀림 / 네트워크 / 저장 실패를 문구로 구분
                  child: message == null
                      ? null
                      : Text(message, style: _LoginText.error, maxLines: 1),
                ),
                const SizedBox(height: 11),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _RememberEmail(
                    value: _rememberEmail,
                    onChanged: enabled
                        ? (value) => setState(() => _rememberEmail = value)
                        : null,
                  ),
                ),
                const SizedBox(height: 55),
                MovieLogButton(
                  label: '로그인',
                  width: double.infinity,
                  isLoading: loading,
                  fontSize: 14,
                  onPressed: enabled ? _submit : null,
                ),
                const SizedBox(height: 21),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('계정이 없나요?', style: _LoginText.prompt),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: enabled ? _openRegister : null,
                      child: const Text('회원가입', style: _LoginText.link),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Challenge: 이메일 저장 체크박스 (shared_preferences에 이메일만)
/// Figma W8-CH01: 22 x 22 radius 4 보라 체크, 왼쪽 2, 글자까지 11
class _RememberEmail extends StatelessWidget {
  const _RememberEmail({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final change = onChanged;
    return InkWell(
      onTap: change == null ? null : () => change(!value),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 22,
              // 기본 Checkbox(18)를 Figma 크기 22로 키움
              child: Transform.scale(
                scale: 22 / 18,
                child: Checkbox(
                  value: value,
                  onChanged: change == null ? null : (v) => change(v ?? false),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  activeColor: AppColors.violet,
                  checkColor: AppColors.white,
                  side: const BorderSide(
                    color: AppColors.checkboxBorder,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 11),
            const Text('이메일 저장', style: _LoginText.remember),
          ],
        ),
      ),
    );
  }
}
