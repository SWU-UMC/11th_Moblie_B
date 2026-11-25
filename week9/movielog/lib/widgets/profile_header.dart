import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'edit_profile_button.dart';

/// 프로필 사진, 닉네임, 가입일, 이메일, 수정 버튼
/// Figma W8-06·CH04: 사진 126, 닉네임 20 Bold, 가입일 12, 이메일 13
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.nickname,
    required this.email,
    required this.onEditPressed,
    this.joinedText,
    this.imagePath,
  });

  final String nickname;
  final String email;

  /// "2026.10.10 가입" (없으면 안 그림)
  final String? joinedText;
  final VoidCallback? onEditPressed;

  /// 이미지 없으면 null (기본 아이콘)
  final String? imagePath;

  static const double _avatarSize = 126;

  static const _secondary = TextStyle(
    fontWeight: FontWeight.w500,
    height: 1.25,
    color: AppColors.textSecondary,
  );

  @override
  Widget build(BuildContext context) {
    final joined = joinedText;
    return Column(
      children: [
        _buildAvatar(),
        const SizedBox(height: 17),
        Text(
          nickname,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.25,
            color: AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (joined != null) ...[
          const SizedBox(height: 5),
          Text(joined, style: _secondary.copyWith(fontSize: 12)),
          const SizedBox(height: 4),
        ] else
          const SizedBox(height: 13),
        Text(email, style: _secondary.copyWith(fontSize: 13)),
        SizedBox(height: joined != null ? 43 : 54),
        EditProfileButton(onPressed: onEditPressed),
      ],
    );
  }

  Widget _buildAvatar() {
    final path = imagePath;
    return ClipOval(
      child: path == null
          ? Container(
              width: _avatarSize,
              height: _avatarSize,
              color: AppColors.violetLight,
              alignment: Alignment.center,
              child: const Icon(
                Icons.person,
                size: 56,
                color: AppColors.violet,
                semanticLabel: '기본 프로필',
              ),
            )
          : Image.asset(
              path,
              width: _avatarSize,
              height: _avatarSize,
              fit: BoxFit.cover,
            ),
    );
  }
}
