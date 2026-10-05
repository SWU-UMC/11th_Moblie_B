import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// 장르를 여러 개 고르는 BottomSheet.
///
/// Checkbox를 바꾸는 동안에는 Sheet 안의 선택만 바뀌고,
/// 확인을 눌러야 고른 장르를 반환합니다.
class GenreFilterSheet extends StatefulWidget {
  const GenreFilterSheet({
    super.key,
    required this.genres,
    required this.initialSelection,
    required this.scrollController,
  });

  final List<String> genres;
  final Set<String> initialSelection;
  final ScrollController scrollController;

  /// 위아래로 드래그해 높이를 조절할 수 있는 BottomSheet를 엽니다.
  static Future<Set<String>?> show(
    BuildContext context, {
    required List<String> genres,
    required Set<String> selected,
  }) {
    return showModalBottomSheet<Set<String>>(
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
  late final Set<String> _selected = {...widget.initialSelection};

  void _toggle(String genre, bool checked) {
    setState(() => checked ? _selected.add(genre) : _selected.remove(genre));
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
        // 목록만 남은 공간에서 스크롤되고, 확인 버튼은 아래에 고정됩니다.
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            itemCount: widget.genres.length,
            itemBuilder: (context, index) {
              final genre = widget.genres[index];
              return CheckboxListTile(
                value: _selected.contains(genre),
                onChanged: (checked) => _toggle(genre, checked ?? false),
                title: Text(genre, style: textTheme.titleMedium),
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
              // 아무것도 고르지 않고 확인하면 빈 Set → 전체 목록
              onPressed: () => Navigator.pop(context, {..._selected}),
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
