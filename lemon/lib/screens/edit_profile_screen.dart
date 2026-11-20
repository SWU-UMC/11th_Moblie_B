import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../view_models/auth_view_model.dart';
import '../view_models/edit_profile_view_model.dart';
import '../widgets/max_runes_formatter.dart';
import '../widgets/movielog_app_bar.dart';
import '../widgets/movielog_button.dart';

/// 프로필 수정 화면입니다. 이메일은 읽기 전용, 닉네임만 바꿀 수 있습니다.
///
/// - 성공: AuthViewModel.member가 이미 교체됐으므로 Snackbar 후 마이페이지로 돌아갑니다.
/// - 입력/중복 오류: 화면에 남아 필드 아래에 보여주고 입력값을 유지합니다.
/// - 401: 세션이 정리되고 Router가 /login으로 보냅니다. (pop하지 않습니다)
/// - 네트워크 오류: Snackbar로 안내하고 로그아웃하지 않습니다.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final member = context.read<AuthViewModel>().member;
    _controller = TextEditingController(text: member?.nickname ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final viewModel = context.read<EditProfileViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    FocusScope.of(context).unfocus();

    final success = await viewModel.save(_controller.text);
    if (!mounted) return;

    if (success) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('프로필을 수정했어요.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      router.pop(); // 마이페이지는 이미 새 닉네임을 보여주고 있습니다.
    } else if (viewModel.message case final message?) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final email = context.select<AuthViewModel, String?>(
      (a) => a.member?.email,
    );
    final viewModel = context.watch<EditProfileViewModel>();
    final saving = viewModel.isSaving;

    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color),
    );
    final labelStyle = textTheme.bodyMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );

    // 저장 중에는 뒤로 가기로 화면을 벗어나지 못하게 합니다.
    return PopScope(
      canPop: !saving,
      child: Scaffold(
        appBar: MovieLogAppBar(
          title: '프로필 수정',
          titleColor: colors.primary,
          leading: IconButton(
            tooltip: '뒤로 가기',
            onPressed: saving ? null : () => context.pop(),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('이메일 (변경할 수 없습니다)', style: labelStyle),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: email,
                          enabled: false, // email은 읽기 전용입니다.
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: colors.surfaceContainerHigh,
                            disabledBorder: border(colors.outlineVariant),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text('닉네임', style: labelStyle),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _controller,
                          enabled: !saving,
                          // Flutter maxLength(grapheme 기준) 대신 검증과 같은 코드포인트 기준으로
                          // 입력을 제한하고 카운터를 표시합니다.
                          inputFormatters: const [
                            MaxRunesFormatter(EditProfileViewModel.maxLength),
                          ],
                          textInputAction: TextInputAction.done,
                          onChanged: (_) {
                            setState(() {}); // 코드포인트 카운터를 갱신합니다.
                            viewModel.onNicknameChanged();
                          },
                          onSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            hintText: '2~12자로 입력해 주세요',
                            counterText:
                                '${runeLength(_controller.text)} / '
                                '${EditProfileViewModel.maxLength}',
                            errorText: viewModel.nicknameError,
                            errorMaxLines: 2,
                            filled: true,
                            fillColor: colors.surfaceContainerLowest,
                            enabledBorder: border(colors.outlineVariant),
                            focusedBorder: border(colors.primary),
                            disabledBorder: border(colors.outlineVariant),
                            errorBorder: border(colors.error),
                            focusedErrorBorder: border(colors.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                MovieLogButton(
                  label: '저장',
                  width: double.infinity,
                  height: 48,
                  isLoading: saving,
                  onPressed: saving ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
