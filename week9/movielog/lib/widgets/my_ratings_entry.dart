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
    return const _MyPageEntry(
      label: '내가 등록한 평점',
      location: AppRoutes.myRatings,
      height: 64,
      color: AppColors.white,
      borderColor: AppColors.entryBorder,
      borderWidth: 1.5,
      fontSize: 16,
    );
  }
}

/// 9주차 '내 즐겨찾기' 행 (내가 등록한 평점 아래)
/// 시각 자료 W9 마이페이지: 평점 행보다 얇은 테두리, 배경색 그대로
class MyFavoritesEntry extends StatelessWidget {
  const MyFavoritesEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return const _MyPageEntry(
      label: '내 즐겨찾기',
      location: AppRoutes.myFavorites,
      height: 52,
      color: AppColors.screenBackground,
      borderColor: AppColors.statBorder,
      borderWidth: 1,
      fontSize: 15,
    );
  }
}

class _MyPageEntry extends StatelessWidget {
  const _MyPageEntry({
    required this.label,
    required this.location,
    required this.height,
    required this.color,
    required this.borderColor,
    required this.borderWidth,
    required this.fontSize,
  });

  final String label;
  final String location;
  final double height;
  final Color color;
  final Color borderColor;
  final double borderWidth;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: borderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(location),
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.only(left: 19, right: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.violet),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
