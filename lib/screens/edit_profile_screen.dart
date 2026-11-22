import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../view_models/auth_view_model.dart';
import '../view_models/edit_profile_view_model.dart';
import '../widgets/movielog_button.dart';

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
    _controller = TextEditingController(
      text: context.read<AuthViewModel>().member?.nickname ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final vm = context.read<EditProfileViewModel>();
    final success = await vm.save(_controller.text);
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('프로필을 수정했어요.')));
      // 저장 중 PopScope가 해제된 프레임에서 마이페이지로 복귀합니다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/my');
      });
    } else if (vm.message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(vm.message!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = context.select<AuthViewModel, String?>(
      (a) => a.member?.email,
    );
    final vm = context.watch<EditProfileViewModel>();
    final saving = vm.status == EditProfileStatus.saving;
    return PopScope(
      canPop: !saving,
      child: Scaffold(
        appBar: AppBar(centerTitle: true, title: const Text('프로필 수정')),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 48).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        TextFormField(
                          initialValue: email,
                          enabled: false,
                          decoration: const InputDecoration(
                            labelText: '이메일 (변경할 수 없습니다)',
                          ),
                        ),
                        const SizedBox(height: 32),
                        TextField(
                          controller: _controller,
                          enabled: !saving,
                          maxLength: 12,
                          decoration: InputDecoration(
                            labelText: '닉네임',
                            errorText: vm.nicknameError,
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: MovieLogButton(
                        label: '저장',
                        width: double.infinity,
                        isLoading: saving,
                        onPressed: saving ? null : _submit,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
