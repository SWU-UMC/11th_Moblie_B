import 'package:flutter/material.dart';

import '../../data/models/tmdb_genre_dto.dart';
import '../../theme/app_colors.dart';

/// 장르 여러 개 고르는 BottomSheet (3주차 Challenge)
/// 확인 눌러야 선택한 id 목록 반환
class GenreFilterSheet extends StatefulWidget {
  const GenreFilterSheet({
    super.key,
    required this.genres,
    required this.initialSelection,
    required this.scrollController,
  });

  final List<TmdbGenreDto> genres;
  final List<int> initialSelection;
  final ScrollController scrollController;

  /// 드래그로 높이 조절되는 BottomSheet 열기
  static Future<List<int>?> show(
    BuildContext context, {
    required List<TmdbGenreDto> genres,
    required List<int> selected,
  }) {
    return showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.warmWhite,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => GenreFilterSheet(
          genres: genres,
          initialSelection: selected,
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  State<GenreFilterSheet> createState() => _GenreFilterSheetState();
}

class _GenreFilterSheetState extends State<GenreFilterSheet> {
  late final Set<int> _selected = {...widget.initialSelection};

  void _toggle(int genreId, bool checked) {
    setState(
      () => checked ? _selected.add(genreId) : _selected.remove(genreId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text('장르 필터', style: textTheme.titleLarge),
        ),
        // 목록만 스크롤, 확인 버튼은 하단 고정
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            itemCount: widget.genres.length,
            itemBuilder: (context, index) {
              final genre = widget.genres[index];
              return CheckboxListTile(
                value: _selected.contains(genre.id),
                onChanged: (checked) => _toggle(genre.id, checked ?? false),
                title: Text(genre.name, style: textTheme.titleMedium),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.violet,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: ElevatedButton(
              // 아무것도 안 고르면 [] → 전체
              onPressed: () => Navigator.pop(context, [
                for (final genre in widget.genres)
                  if (_selected.contains(genre.id)) genre.id,
              ]),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 56),
                backgroundColor: AppColors.violet,
                foregroundColor: AppColors.white,
                textStyle: textTheme.titleMedium,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('확인'),
            ),
          ),
        ),
      ],
    );
  }
}
