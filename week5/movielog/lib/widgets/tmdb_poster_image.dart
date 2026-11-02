import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// TMDB 이미지 경로(poster_path·backdrop_path)를 URL로 바꿔 보여줍니다.
///
/// 경로가 null이거나 이미지를 불러오지 못하면 placeholder를 보여줍니다.
/// [width]·[height]를 비우면 부모 크기를 채웁니다.
class TmdbPosterImage extends StatelessWidget {
  const TmdbPosterImage({
    super.key,
    required this.posterPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.size = 'w500',
  });

  final String? posterPath;
  final double? width;
  final double? height;
  final BoxFit fit;

  /// TMDB 이미지 크기 (w342, w500, w780 …)
  final String size;

  static const _baseUrl = 'https://image.tmdb.org/t/p';

  String? get imageUrl {
    final path = posterPath;
    if (path == null || path.isEmpty) return null;
    return '$_baseUrl/$size$path';
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url == null) return _placeholder();

    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => _placeholder(),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _placeholder(loading: true),
    );
  }

  Widget _placeholder({bool loading = false}) {
    return Container(
      width: width,
      height: height,
      color: AppColors.divider,
      alignment: Alignment.center,
      child: loading
          ? null
          : const Icon(
              Icons.image_not_supported_outlined,
              color: AppColors.hint,
              semanticLabel: '포스터 없음',
            ),
    );
  }
}
