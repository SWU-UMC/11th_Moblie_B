import 'package:flutter/material.dart';

import '../models/movie.dart';

/// 홈과 영화 목록에서 함께 쓰는 포스터 카드입니다.
class MovieCard extends StatefulWidget {
  const MovieCard({super.key, required this.movie, required this.onTap});

  final Movie movie;
  final VoidCallback onTap;

  @override
  State<MovieCard> createState() => _MovieCardState();
}

class _MovieCardState extends State<MovieCard> {
  bool _showFocus = false;

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // 탭은 GestureDetector로 처리하고, 키보드 사용자도 Tab으로 포커스를 옮겨
    // Enter/Space로 카드를 열 수 있도록 FocusableActionDetector를 함께 둡니다.
    return FocusableActionDetector(
      onShowFocusHighlight: (value) => setState(() => _showFocus = value),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        label: movie.title,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 부모가 정해준 높이에서 글자 영역을 뺀 나머지를 포스터가 채웁니다.
              // 글자 크기가 커져도 카드가 넘치지 않습니다.
              Expanded(
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: _showFocus
                        ? Border.all(color: colors.primary, width: 3)
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(movie.posterPath, fit: BoxFit.cover),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: _RatingBadge(rating: movie.rating),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                movie.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${movie.year} · ${movie.genres.first}',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xB3000000),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 14, color: Colors.white),
          const SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1),
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
