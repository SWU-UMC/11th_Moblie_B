import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// 가로로 스크롤되는 장르 Chip 목록. "전체"는 선택한 장르가 없는 상태입니다.
class GenreChipBar extends StatelessWidget {
  const GenreChipBar({
    super.key,
    required this.genres,
    required this.selectedGenres,
    required this.onSelected,
  });

  final List<String> genres;
  final Set<String> selectedGenres;

  /// 전체를 누르면 빈 Set, 장르를 누르면 그 장르 하나만 담은 Set을 전달합니다.
  final ValueChanged<Set<String>> onSelected;

  @override
  Widget build(BuildContext context) {
    final labels = ['전체', ...genres];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: labels.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final label = labels[index];
          final selected = isAll
              ? selectedGenres.isEmpty
              : selectedGenres.contains(label);

          return ChoiceChip(
            label: Text(label),
            selected: selected,
            showCheckmark: false,
            onSelected: (_) => onSelected(isAll ? {} : {label}),
            labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: selected ? AppColors.white : AppColors.violetDark,
            ),
            selectedColor: AppColors.violet,
            backgroundColor: AppColors.violetLight,
            side: BorderSide.none,
            shape: const StadiumBorder(),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }
}
