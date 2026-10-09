import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import 'edit_profile_button.dart';

/// 프로필 이미지, 닉네임, 소개, 프로필 수정 버튼
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.nickname,
    required this.bio,
    this.imagePath,
  });

  final String nickname;
  final String bio;

  /// 프로필 이미지가 없으면 null (기본 아이콘 표시)
  final String? imagePath;

  static const double _avatarSize = 128;
  static const double _borderWidth = 2;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        _buildAvatar(),
        const SizedBox(height: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                nickname,
                style: textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            SvgPicture.asset(
              'assets/icons/movie.svg',
              width: 20,
              height: 20,
              colorFilter: const ColorFilter.mode(
                AppColors.violet,
                BlendMode.srcIn,
              ),
              semanticsLabel: '영화 아이콘',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(bio, textAlign: TextAlign.center, style: textTheme.bodyLarge),
        const SizedBox(height: 16),
        const EditProfileButton(),
      ],
    );
  }

  Widget _buildAvatar() {
    final path = imagePath;
    const innerSize = _avatarSize - _borderWidth * 2;

    return Container(
      width: _avatarSize,
      height: _avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.violetBorder, width: _borderWidth),
      ),
      child: ClipOval(
        child: path == null
            ? Container(
                color: AppColors.violetLight,
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  'assets/icons/person.svg',
                  width: 56,
                  height: 56,
                  colorFilter: const ColorFilter.mode(
                    AppColors.violet,
                    BlendMode.srcIn,
                  ),
                  semanticsLabel: '기본 프로필',
                ),
              )
            : Image.asset(
                path,
                width: innerSize,
                height: innerSize,
                fit: BoxFit.cover,
              ),
      ),
    );
  }
}
