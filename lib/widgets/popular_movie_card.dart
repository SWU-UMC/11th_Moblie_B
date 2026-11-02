import 'package:flutter/material.dart';

import '../data/models/tmdb_movie_dto.dart';
import 'tmdb_poster_image.dart';

/// 홈 인기 영화 가로 목록의 카드입니다. 왼쪽 위에 순위를 표시합니다.
class PopularMovieCard extends StatefulWidget {
  const PopularMovieCard({
    super.key,
    required this.rank,
    required this.movie,
    required this.onTap,
  });

  final int rank;
  final TmdbMovieDto movie;
  final VoidCallback onTap;

  @override
  State<PopularMovieCard> createState() => _PopularMovieCardState();
}

class _PopularMovieCardState extends State<PopularMovieCard> {
  bool _showFocus = false;

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // 키보드 사용자도 Tab으로 포커스를 옮겨 Enter/Space로 카드를 열 수 있습니다.
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
      // excludeSemantics로 자식의 탭 동작이 빠지므로 onTap을 직접 연결합니다.
      child: Semantics(
        button: true,
        label: '인기 ${widget.rank}위 ${movie.title}',
        onTap: widget.onTap,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                        TmdbPosterImage(
                          posterPath: movie.posterPath,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                        Positioned(
                          top: 8,
                          left: 8,
                          child: _RankBadge(rank: widget.rank),
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
              Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: Color(0xFFE0B04B),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    movie.voteAverage.toStringAsFixed(1),
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xB3000000),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$rank',
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }
}
