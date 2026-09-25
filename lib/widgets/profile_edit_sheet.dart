import 'package:flutter/material.dart';

typedef ProfileEditResult = ({String nickname, String bio});

/// 닉네임과 소개를 수정하는 BottomSheet입니다. 저장하면 수정한 값을, 닫으면 null을 돌려줍니다.
Future<ProfileEditResult?> showProfileEditSheet(
  BuildContext context, {
  required String nickname,
  required String bio,
}) {
  return showModalBottomSheet<ProfileEditResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ProfileEditSheet(nickname: nickname, bio: bio),
  );
}

class _ProfileEditSheet extends StatefulWidget {
  const _ProfileEditSheet({required this.nickname, required this.bio});

  final String nickname;
  final String bio;

  @override
  State<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<_ProfileEditSheet> {
  late final _nicknameController = TextEditingController(text: widget.nickname);
  late final _bioController = TextEditingController(text: widget.bio);

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  bool get _canSave => _nicknameController.text.trim().length >= 2;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // 키보드가 올라오면 BottomSheet도 함께 올라가도록 합니다.
    // 화면이 작아 내용이 넘치면 스크롤해서 저장 버튼까지 볼 수 있습니다.
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '프로필 수정',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nicknameController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: '닉네임',
              errorText: _canSave ? null : '닉네임은 2자 이상이어야 합니다.',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bioController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: '소개'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _canSave
                ? () => Navigator.of(context).pop((
                    nickname: _nicknameController.text.trim(),
                    bio: _bioController.text.trim(),
                  ))
                : null,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}
