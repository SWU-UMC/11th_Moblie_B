import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/mock_movies.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../view_models/learning_member_session.dart';
import '../view_models/movie_detail_view_model.dart';
import '../widgets/movie_error_view.dart';
import 'movie_detail_screen.dart';

/// 영화 상세 화면의 시작점입니다.
///
/// 목록에서 넘긴 TMDB DTO(extra)가 있으면 그대로 쓰고, 주소로 바로 들어와 extra가 없으면
/// 경로의 movieId로 TMDB `GET /movie/{movie_id}`를 다시 조회합니다.
/// 홈의 추천 카드처럼 mock 영화(문자열 id)는 평점 서버에 저장할 수 없으므로 ViewModel 없이 그립니다.
class MovieDetailLoader extends StatefulWidget {
  const MovieDetailLoader({
    super.key,
    required this.movieId,
    this.initialMovie,
  });

  /// 경로의 영화 ID입니다. TMDB 영화는 TMDB id, 추천 카드는 mock id입니다.
  final String movieId;
  final TmdbMovieDto? initialMovie;

  @override
  State<MovieDetailLoader> createState() => _MovieDetailLoaderState();
}

class _MovieDetailLoaderState extends State<MovieDetailLoader> {
  Future<TmdbMovieDto>? _movieFuture;

  @override
  void initState() {
    super.initState();
    _movieFuture = _startLoad();
  }

  /// TMDB 영화가 필요할 때만 Future를 만듭니다. build마다 새로 만들지 않습니다.
  Future<TmdbMovieDto>? _startLoad() {
    final initial = widget.initialMovie;
    if (initial != null) return Future.value(initial);
    if (findMovieById(widget.movieId) != null) return null;
    final id = int.tryParse(widget.movieId);
    if (id == null || id < 1) return null;
    return context.read<TmdbMovieService>().fetchMovieDetail(id);
  }

  @override
  Widget build(BuildContext context) {
    final mockMovie = findMovieById(widget.movieId);
    final future = _movieFuture;
    if (future == null) {
      if (mockMovie == null) {
        return const MovieDetailScaffold(
          body: Center(child: Text('영화 ID가 올바르지 않습니다.')),
        );
      }
      return MovieDetailScreen(movie: MovieDetailData.fromMock(mockMovie));
    }

    return FutureBuilder<TmdbMovieDto>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const MovieDetailScaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final movie = snapshot.data;
        if (snapshot.hasError || movie == null) {
          final error = snapshot.error;
          debugPrint('영화 상세 요청 실패: $error');
          // 404는 재시도해도 같으므로 "찾을 수 없어요"를 보여줍니다.
          if (error is DioException && error.response?.statusCode == 404) {
            return const MovieDetailScaffold(
              body: Center(child: Text('영화 정보를 찾을 수 없어요.')),
            );
          }
          return MovieDetailScaffold(
            body: MovieErrorView(
              message: '영화 정보를 불러오지 못했어요',
              onRetry: () => setState(() => _movieFuture = _startLoad()),
            ),
          );
        }
        return ChangeNotifierProvider<MovieDetailViewModel>(
          create: (context) => MovieDetailViewModel(
            context.read<RatingApiService>(),
            context.read<LearningMemberSession>().memberId,
            movie,
          ),
          child: MovieDetailScreen(movie: MovieDetailData.fromTmdb(movie)),
        );
      },
    );
  }
}
