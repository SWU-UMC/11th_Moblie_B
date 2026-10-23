import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/movie.dart';
import '../../router/app_routes.dart';
import '../../theme/app_colors.dart';

/// 홈 상단의 추천 영화 카드. 포스터 위에 정보와 상세보기 버튼을 겹쳐 둡니다.
class FeaturedMovieCard extends StatelessWidget {
  const FeaturedMovieCard({super.key, required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    void openDetail() => context.push(AppRoutes.movieDetailOf(movie.id));

    return GestureDetector(
      onTap: openDetail,
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(movie.posterAsset, fit: BoxFit.cover),
              // 아래쪽 글자가 잘 보이도록 어둡게 덮는 그라데이션
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC000000)],
                    stops: [0.4, 1],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.violetDark,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '추천 신작',
                        style: textTheme.labelMedium?.copyWith(
                          color: AppColors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      movie.title,
                      style: textTheme.headlineMedium?.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                    Text(
                      '${movie.genres.join(' · ')} · ${movie.runtimeMinutes}분',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: openDetail,
                        icon: const Icon(Icons.info, size: 18),
                        label: const Text('상세보기'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          backgroundColor: AppColors.violetDark,
                          foregroundColor: AppColors.white,
                          textStyle: textTheme.labelLarge,
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
