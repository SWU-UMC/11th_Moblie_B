import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 선호 장르 + 칩 목록 (Figma W8-06: 제목 17 Bold, 칩 높이 33 연보라)
class FavoriteGenres extends StatelessWidget {
  const FavoriteGenres({super.key, required this.genres});

  final List<String> genres;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '선호하는 장르',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            height: 1.25,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final genre in genres)
              Container(
                height: 33,
                padding: const EdgeInsets.symmetric(horizontal: 17),
                decoration: BoxDecoration(
                  color: AppColors.genreChip,
                  borderRadius: BorderRadius.circular(17),
                ),
                // alignment 주면 칩이 가로로 꽉 차서 widthFactor 1로 글자만큼
                child: Align(
                  widthFactor: 1,
                  child: Text(
                    genre,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                      color: AppColors.violet,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
