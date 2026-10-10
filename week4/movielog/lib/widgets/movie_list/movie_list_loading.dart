import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'movie_grid.dart';

/// 영화 목록 Loading 상태: 카드 모양의 Skeleton을 보여줍니다.
class MovieListLoading extends StatelessWidget {
  const MovieListLoading({super.key});

  static const _skeletonCount = 6;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '영화 목록을 불러오는 중',
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: MovieGrid.padding,
        itemCount: _skeletonCount,
        gridDelegate: MovieGrid.gridDelegate,
        itemBuilder: (context, index) => const _SkeletonCard(),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _block(radius: 8)),
        const SizedBox(height: 8),
        FractionallySizedBox(widthFactor: 0.8, child: _block(height: 16)),
        const SizedBox(height: 4),
        FractionallySizedBox(widthFactor: 0.5, child: _block(height: 12)),
      ],
    );
  }

  Widget _block({double? height, double radius = 4}) => Container(
    height: height,
    decoration: BoxDecoration(
      color: AppColors.divider,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}
