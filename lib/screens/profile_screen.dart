import 'package:flutter/material.dart';

import '../widgets/edit_profile_button.dart';
import '../widgets/favorite_genres.dart';
import '../widgets/movielog_app_bar.dart';
import '../widgets/profile_edit_sheet.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_stats.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // 프로필 정보는 서버 없이 화면 내부 상태로만 관리합니다.
  String _nickname = '무비러버';
  String _bio = '매주 주말엔 영화관으로 출근하는 프로 관람객. 좋은 영화를 보고 기록하는 것을 좋아합니다.';

  Future<void> _editProfile() async {
    final result = await showProfileEditSheet(
      context,
      nickname: _nickname,
      bio: _bio,
    );
    if (result == null || !mounted) return;
    setState(() {
      _nickname = result.nickname;
      _bio = result.bio;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('프로필을 수정했어요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: MovieLogAppBar(
        title: '내 프로필',
        titleColor: colors.primary,
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProfileHeader(nickname: _nickname, bio: _bio),
              const SizedBox(height: 24),
              Center(child: EditProfileButton(onPressed: _editProfile)),
              const SizedBox(height: 32),
              const ProfileStats(),
              const SizedBox(height: 40),
              const FavoriteGenres(),
            ],
          ),
        ),
      ),
    );
  }
}
