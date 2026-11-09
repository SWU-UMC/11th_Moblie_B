import 'package:flutter/material.dart';

import '../data/models/tmdb_genre_dto.dart';

/// 영화 목록 상단의 가로 스크롤 장르 Chip 목록입니다.
/// 맨 앞의 "전체"는 장르 ID null로 전달합니다.
class GenreFilterChips extends StatelessWidget {
  const GenreFilterChips({
    super.key,
    required this.genres,
    required this.selectedGenreId,
    required this.onSelected,
    this.enabled = true,
  });

  static const allGenresLabel = '전체';

  final List<TmdbGenreDto> genres;
  final int? selectedGenreId;
  final ValueChanged<int?> onSelected;

  /// false면 요청 중으로 보고 Chip을 누를 수 없게 합니다.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // 기본 높이 40에 글자 확대로 늘어난 만큼을 더해, 큰 글씨 설정에서도 Chip이 잘리지 않게 합니다.
    final labelSize = textTheme.labelLarge?.fontSize ?? 14;
    final extraHeight =
        MediaQuery.textScalerOf(context).scale(labelSize) - labelSize;

    final items = <(int?, String)>[
      (null, allGenresLabel),
      for (final genre in genres) (genre.id, genre.name),
    ];

    return SizedBox(
      height: 40 + extraHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (id, name) = items[index];
          final selected = id == selectedGenreId;
          return ChoiceChip(
            label: Text(name),
            selected: selected,
            onSelected: enabled ? (_) => onSelected(id) : null,
            showCheckmark: false,
            shape: const StadiumBorder(),
            side: BorderSide.none,
            backgroundColor: colors.surfaceContainerHighest,
            selectedColor: colors.primary,
            disabledColor: selected
                ? colors.primary.withValues(alpha: 0.6)
                : colors.surfaceContainerHighest,
            labelStyle: textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: selected ? colors.onPrimary : colors.onSurfaceVariant,
            ),
          );
        },
      ),
    );
  }
}
