import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../view_models/auth_view_model.dart';
import '../view_models/edit_profile_view_model.dart';
import '../widgets/auth/auth_text_field.dart';
import '../widgets/movielog_button.dart';
import '../widgets/profile/discard_changes_dialog.dart';

/// W8-07 프로필 닉네임 수정 / W8-08 저장 중 / W8-09 중복 오류
/// 이메일은 읽기 전용, 닉네임만 PATCH /v8/members/me
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nickname;
  late final TextEditingController _email;

  @override
  void initState() {
    super.initState();
    final member = context.read<AuthViewModel>().member;
    _nickname = TextEditingController(text: member?.nickname ?? '');
    _email = TextEditingController(text: member?.email ?? '');
  }

  @override
  void dispose() {
    _nickname.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final viewModel = context.read<EditProfileViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    FocusScope.of(context).unfocus();

    final success = await viewModel.save(_nickname.text);
    if (!mounted) return;

    if (success) {
      messenger.showSnackBar(const SnackBar(content: Text('프로필을 수정했어요.')));
      // 저장 끝났으니 변경 확인 Dialog 없이 바로 닫음
      // (PopScope canPop은 다음 build에야 바뀌어서 maybePop 말고 pop)
      navigator.pop(); // 마이페이지엔 이미 새 닉네임 반영됨
    } else if (viewModel.message case final message?) {
      // 입력칸 문제 말고 네트워크 등은 Snackbar
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// Challenge: 바뀐 내용 있으면 뒤로가기 전에 확인
  Future<void> _onPopBlocked() async {
    final viewModel = context.read<EditProfileViewModel>();
    if (viewModel.isSaving) return; // 저장 중엔 못 나감
    final leave = await DiscardChangesDialog.show(context);
    if (!mounted || !leave) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<EditProfileViewModel>();
    final saving = viewModel.isSaving;
    // 변경 없고 저장 중 아닐 때만 바로 뒤로가기
    final canPop = !saving && !viewModel.hasChanges(_nickname.text);

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onPopBlocked();
      },
      child: Scaffold(
        backgroundColor: AppColors.screenBackground,
        appBar: AppBar(
          toolbarHeight: 64,
          centerTitle: true,
          backgroundColor: AppColors.screenBackground,
          surfaceTintColor: Colors.transparent,
          foregroundColor: AppColors.textPrimary,
          title: const Text(
            '프로필 수정',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.25,
              color: AppColors.violet,
            ),
          ),
        ),
        body: SafeArea(
          child: Padding(
            // Figma W8-07: 라벨 118, 이메일칸 142, 닉네임 229/253, 저장 724(아래 76)
            padding: const EdgeInsets.fromLTRB(24, 54, 24, 76),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _FieldLabel('이메일 (변경할 수 없습니다)'),
                const SizedBox(height: 6),
                AuthTextField(
                  controller: _email,
                  enabled: true,
                  readOnly: true, // email은 바꿀 수 없음
                  hintText: '이메일',
                ),
                const SizedBox(height: 38),
                const _FieldLabel('닉네임'),
                const SizedBox(height: 6),
                AuthTextField(
                  controller: _nickname,
                  enabled: !saving,
                  hintText: '2~12자',
                  maxLength: 12,
                  textInputAction: TextInputAction.done,
                  errorText: viewModel.nicknameError,
                  hideErrorText: true, // 문구는 아래 카운터 줄에
                  onChanged: (_) {
                    viewModel.onNicknameChanged();
                    setState(() {}); // 카운터·변경 여부(canPop) 다시 계산
                  },
                  onFieldSubmitted: (_) => saving ? null : _submit(),
                ),
                const SizedBox(height: 9),
                // Figma: 왼쪽 오류 문구, 오른쪽 "4 / 12"
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        viewModel.nicknameError ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.25,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                    // Figma: 카운터는 오류 문구보다 6 아래
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${_nickname.text.characters.length} / 12',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.25,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                MovieLogButton(
                  label: '저장',
                  width: double.infinity,
                  fontSize: 14,
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: AppColors.textSecondary,
      ),
    );
  }
}
