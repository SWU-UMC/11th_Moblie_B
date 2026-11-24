import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// TMDB 이미지 경로 → URL로 바꿔서 표시
/// 경로 없거나 로딩 실패하면 placeholder
/// width, height 안 주면 부모 크기
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

  /// 이미지 사이즈 (w342, w500 ...)
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
