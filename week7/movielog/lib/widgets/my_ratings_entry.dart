import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_routes.dart';
import '../theme/app_colors.dart';

/// 마이페이지 '내가 등록한 평점' 행
class MyRatingsEntry extends StatelessWidget {
  const MyRatingsEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.violetLight),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        title: Text(
          '내가 등록한 평점',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.violet),
        onTap: () => context.push(AppRoutes.myRatings),
      ),
    );
  }
}
