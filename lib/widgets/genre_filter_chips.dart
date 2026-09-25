import 'package:flutter/material.dart';

/// 영화 목록 상단의 가로 스크롤 장르 Chip 목록입니다.
class GenreFilterChips extends StatelessWidget {
  const GenreFilterChips({
    super.key,
    required this.genres,
    required this.selectedGenre,
    required this.onSelected,
  });

  final List<String> genres;
  final String selectedGenre;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // 기본 높이 40에 글자 확대로 늘어난 만큼을 더해, 큰 글씨 설정에서도 Chip이 잘리지 않게 합니다.
    final labelSize = textTheme.labelLarge?.fontSize ?? 14;
    final extraHeight =
        MediaQuery.textScalerOf(context).scale(labelSize) - labelSize;

    return SizedBox(
      height: 40 + extraHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: genres.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final genre = genres[index];
          final selected = genre == selectedGenre;
          return ChoiceChip(
            label: Text(genre),
            selected: selected,
            onSelected: (_) => onSelected(genre),
            showCheckmark: false,
            shape: const StadiumBorder(),
            side: BorderSide.none,
            backgroundColor: colors.surfaceContainerHighest,
            selectedColor: colors.primary,
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
