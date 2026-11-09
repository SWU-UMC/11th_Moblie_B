import 'package:flutter/material.dart';

/// TMDB poster_path로 포스터를 그립니다.
/// URL 조합, null 처리, 로드 실패 처리를 화면마다 반복하지 않도록 모았습니다.
class TmdbPosterImage extends StatelessWidget {
  const TmdbPosterImage({
    super.key,
    required this.posterPath,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
  });

  final String? posterPath;
  final double width;
  final double height;
  final BoxFit fit;

  static const _baseUrl = 'https://image.tmdb.org/t/p';
  static const _size = 'w500';

  String? get _imageUrl {
    if (posterPath == null || posterPath!.isEmpty) return null;
    return '$_baseUrl/$_size$posterPath';
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _imageUrl;

    // poster_path가 null이면 요청하지 않고 placeholder를 보여줍니다.
    if (imageUrl == null) return _placeholder();

    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      // 주소는 있지만 이미지를 받지 못한 경우에도 같은 placeholder를 씁니다.
      errorBuilder: (_, _, _) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported_outlined),
    );
  }
}
