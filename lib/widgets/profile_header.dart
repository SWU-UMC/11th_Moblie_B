import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipOval(
          child: Image.asset(
            'assets/images/profile/profile_movielog.jpg',
            width: 80,
            height: 80,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('무비러버', style: textTheme.titleLarge),
            const SizedBox(width: 8),
            SvgPicture.asset(
              'assets/icons/check_circle.svg',
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(colors.primary, BlendMode.srcIn),
              semanticsLabel: '인증된 프로필',
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text('좋아하는 영화를 기록하고 있어요'),
      ],
    );
  }
}
