import 'package:flutter/material.dart';
// import 'package:flutter_svg/flutter_svg.dart';
import 'common_app_bar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(
        title: '내 프로필',
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, 
            children: const [
              SizedBox(height: 24),
              ProfileHeader(),
              SizedBox(height: 16),
              EditProfileButton(),
              SizedBox(height: 24),
              ProfileStats(),
              SizedBox(height: 24),
              FavoriteGenres(),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: colors.secondary,
              width: 3,
            ),
          ),
          child: const CircleAvatar(
            radius: 44,
            backgroundImage: AssetImage('assets/images/profile/profile_movielog.jpg'),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '무비러버',
          style: textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          '좋아하는 영화를 기록하고 있어요',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class ProfileStats extends StatelessWidget {
  const ProfileStats({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        StatItem(label: '본 영화', value: '24'),
        SizedBox(width: 12),
        StatItem(label: '평점', value: '418'),
        SizedBox(width: 12),
        StatItem(label: '즐겨찾기', value: '7'),
      ],
    );
  }
}

class EditProfileButton extends StatelessWidget {
  const EditProfileButton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.surface, 
            foregroundColor: colors.primary,
            elevation: 0,
            side: BorderSide(color: colors.primary),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          // const 키워드 제거됨 (컴파일 오류 해결)
          child: Text(
            '프로필 수정',
            style: textTheme.labelLarge,
          ),
        ),
      ],
    );
  }
}

class FavoriteGenres extends StatelessWidget {
  const FavoriteGenres({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '선호하는 장르',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildChip(context, '드라마'),
            const SizedBox(width: 8),
            _buildChip(context, 'SF'),
            const SizedBox(width: 8),
            _buildChip(context, '애니메이션'),
          ],
        ),
      ],
    );
  }

  Widget _buildChip(BuildContext context, String labelText) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        labelText,
        style: textTheme.labelLarge,
      ),
    );
  }
}

class StatItem extends StatelessWidget {
  const StatItem({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: 104,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceVariant, // [수정] 새 배경색 (밝은 회색)
        border: Border.all(
          color: colors.outlineVariant, // [추가] 새 테두리색 (기존 배경색)
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: textTheme.labelSmall,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: textTheme.titleLarge,
          ),
        ],
      ),
    );
  }
}