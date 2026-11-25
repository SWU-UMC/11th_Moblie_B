import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_routes.dart';
import '../theme/app_colors.dart';

/// 마이페이지 '내가 등록한 평점' 행
/// Figma W8-06: 358 x 64, radius 12, 테두리 1.5 #D6C9E8, 글자 16 Bold
class MyRatingsEntry extends StatelessWidget {
  const MyRatingsEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.entryBorder, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.myRatings),
        child: const SizedBox(
          height: 64,
          child: Padding(
            padding: EdgeInsets.only(left: 19, right: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '내가 등록한 평점',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.violet),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
