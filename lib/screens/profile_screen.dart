import 'package:flutter/material.dart';

import '../widgets/edit_profile_button.dart';
import '../widgets/favorite_genres.dart';
import '../widgets/movielog_app_bar.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_stats.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MovieLogAppBar(title: '프로필'),
      body: const SafeArea(child: ProfileBody()),
    );
  }
}

class ProfileBody extends StatelessWidget {
  const ProfileBody({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ProfileHeader(),
          const SizedBox(height: 24),
          const ProfileStats(),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 24),
            child: const FavoriteGenres(),
          ),
          const EditProfileButton(),
        ],
      ),
    );
  }
}
