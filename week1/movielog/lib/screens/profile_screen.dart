import 'package:flutter/material.dart';

import '../models/profile_stat.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/favorite_genres.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_stats.dart';

/// W1-01 내 프로필
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const _stats = [
    ProfileStat(label: '본 영화', value: '342'),
    ProfileStat(label: '평점', value: '4.2'),
    ProfileStat(label: '즐겨찾기', value: '58'),
  ];

  static const _genres = ['드라마', 'SF', '애니메이션'];

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: CommonAppBar(title: '내 프로필'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProfileHeader(
                nickname: '무비러버',
                bio: '매주 주말엔 영화관으로 출근하는 프로 관람객. '
                    '좋은 영화를 보고 기록하는 것을 좋아합니다.',
                imagePath: 'assets/images/profile/profile_movielog.jpg',
              ),
              SizedBox(height: 32),
              ProfileStats(stats: _stats),
              SizedBox(height: 32),
              FavoriteGenres(genres: _genres),
            ],
          ),
        ),
      ),
    );
  }
}
