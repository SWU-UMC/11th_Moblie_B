import 'package:flutter/material.dart';

import '../../data/models/tmdb_genre_dto.dart';
import '../../theme/app_colors.dart';

/// Genre API로 받은 장르를 가로 Chip 목록으로 보여줍니다.
/// "전체"는 선택한 장르가 없는 상태입니다.
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

  /// 전체를 누르면 빈 List, 장르를 누르면 그 장르 id 하나만 담은 List
  final ValueChanged<List<int>> onSelected;

  /// 영화를 불러오는 중에는 장르를 바꿀 수 없습니다.
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
