import 'package:flutter/material.dart';

import '../../data/models/tmdb_genre_dto.dart';
import '../../theme/app_colors.dart';

/// 장르 Chip 가로 목록
/// '전체' = 선택한 장르 없음
class GenreChipBar extends StatelessWidget {
  const GenreChipBar({
    super.key,
    required this.genres,
    required this.selectedGenreIds,
    required this.onSelected,
    this.enabled = true,
  });

  final List<TmdbGenreDto> genres;
  final List<int> selectedGenreIds;

  /// 전체면 [], 장르면 [id]
  final ValueChanged<List<int>> onSelected;

  /// 로딩 중엔 비활성화
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: genres.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final genre = isAll ? null : genres[index - 1];
          final selected = isAll
              ? selectedGenreIds.isEmpty
              : selectedGenreIds.contains(genre!.id);

          return ChoiceChip(
            label: Text(isAll ? '전체' : genre!.name),
            selected: selected,
            showCheckmark: false,
            onSelected: enabled
                ? (_) => onSelected(isAll ? const [] : [genre!.id])
                : null,
            labelStyle: textTheme.labelMedium?.copyWith(
              color: selected ? AppColors.white : AppColors.violetDark,
            ),
            selectedColor: AppColors.violet,
            backgroundColor: AppColors.violetLight,
            disabledColor: selected
                ? AppColors.disabledButton
                : AppColors.cardBackground,
            side: BorderSide.none,
            shape: const StadiumBorder(),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }
}
