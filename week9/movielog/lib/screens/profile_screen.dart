import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/member_info.dart';
import '../models/profile_stat.dart';
import '../router/app_routes.dart';
import '../theme/app_colors.dart';
import '../view_models/auth_view_model.dart';
import '../widgets/favorite_genres.dart';
import '../widgets/movielog_button.dart';
import '../widgets/my_ratings_entry.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_stats.dart';

/// "2026.10.10 가입" (Challenge, 기기 시간대 기준)
String formatJoinedDate(DateTime createdAt) {
  final local = createdAt.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}.${two(local.month)}.${two(local.day)} 가입';
}

/// W8-06 마이페이지·로그아웃 / CH02 로딩 / CH03 실패·재시도 / CH04 가입일
/// 닉네임·이메일·가입일은 MainScreen이 불러온 AuthViewModel.member 구독
/// 사진·통계·장르는 기존 디자인 예시 그대로 (GET me엔 없음)
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const stats = [
    ProfileStat(label: '본 영화', value: '342'),
    ProfileStat(label: '평점', value: '4.2'),
    ProfileStat(label: '즐겨찾기', value: '58'),
  ];

  static const genres = ['드라마', 'SF', '애니메이션'];

  @override
  Widget build(BuildContext context) {
    // read 말고 select → 닉네임 수정되면 바로 다시 그림
    final member = context.select<AuthViewModel, MemberInfo?>((a) => a.member);
    final memberStatus = context.select<AuthViewModel, MemberLoadStatus>(
      (a) => a.memberStatus,
    );

    final Widget body;
    if (member != null) {
      body = _ProfileContent(member: member);
    } else if (memberStatus == MemberLoadStatus.error) {
      // Challenge: 실패해도 로그아웃 안 하고 재시도
      body = _MemberError(
        onRetry: () => context.read<AuthViewModel>().loadMember(force: true),
      );
    } else {
      // Challenge: 불러오는 동안 화면 전체 인디케이터
      body = const Center(
        child: CircularProgressIndicator(
          color: AppColors.violet,
          semanticsLabel: '내 정보 불러오는 중',
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      appBar: AppBar(
        toolbarHeight: 64,
        backgroundColor: AppColors.screenBackground,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: const Text(
          '내 프로필',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.25,
            color: AppColors.violet,
          ),
        ),
        actions: [
          // Figma: 내 정보 있을 때만 (로딩·실패 화면엔 없음)
          if (member != null)
            TextButton(
              // 토큰·member 지우면 Router가 /login으로 보냄 (직접 이동 안 함)
              onPressed: () => context.read<AuthViewModel>().logout(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.violet,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('로그아웃'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(child: body),
    );
  }
}

/// Figma W8-06 세로 위치: 사진 89, 닉네임 232, 수정 341, 통계 414, 평점 526, 장르 617
class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.member});

  final MemberInfo member;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 25, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProfileHeader(
            nickname: member.nickname,
            email: member.email,
            joinedText: formatJoinedDate(member.createdAt),
            imagePath: 'assets/images/profile/profile_movielog.jpg',
            onEditPressed: () => context.push(AppRoutes.profileEdit),
          ),
          const SizedBox(height: 33),
          const ProfileStats(stats: ProfileScreen.stats),
          const SizedBox(height: 26),
          const MyRatingsEntry(),
          const SizedBox(height: 10),
          // 9주차: 평점 행 아래 내 즐겨찾기 (member 있을 때만 이 Content가 그려짐)
          const MyFavoritesEntry(),
          const SizedBox(height: 27),
          const FavoriteGenres(genres: ProfileScreen.genres),
        ],
      ),
    );
  }
}

/// Challenge W8-CH03: 내 정보 실패·재시도 (16 SemiBold, 버튼 218 x 44)
class _MemberError extends StatelessWidget {
  const _MemberError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '내 정보를 불러오지 못했어요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.25,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 28),
            MovieLogButton(
              label: '다시 시도',
              width: 218,
              fontSize: 14,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
