import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/session/session_guard.dart';
import '../data/mock_movies.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/favorite_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../view_models/auth_view_model.dart';
import '../view_models/favorite_detail_view_model.dart';
import '../view_models/movie_detail_view_model.dart';
import '../view_models/session_ratings_view_model.dart';
import '../widgets/movie_error_view.dart';
import '../widgets/movielog_button.dart';
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
        return _SessionFavoriteScope(
          movieId: movie.id,
          child: ChangeNotifierProvider<MovieDetailViewModel>(
            create: (context) => MovieDetailViewModel(
              context.read<SessionRatingsViewModel>(),
              movie,
            ),
            child: MovieDetailScreen(movie: MovieDetailData.fromTmdb(movie)),
          ),
        );
      },
    );
  }
}

/// TMDB 영화 상세에 현재 세션의 [FavoriteDetailViewModel]을 제공합니다.
///
/// 내 정보(member)가 준비되고 [SessionGuard]의 계정과 일치할 때까지 로딩을 보여주고,
/// `ValueKey(email:generation)`으로 계정·세션이 바뀌면 ViewModel을 새로 만듭니다.
/// (같은 계정에서 닉네임만 바뀌면 key가 그대로라 기존 ViewModel을 유지합니다)
class _SessionFavoriteScope extends StatelessWidget {
  const _SessionFavoriteScope({required this.movieId, required this.child});

  final int movieId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final member = auth.member;
    final guard = context.read<SessionGuard>();

    if (member == null || guard.accountId != member.email) {
      // 탭 Shell을 거치지 않고 바로 열린 경우에도 내 정보를 한 번 불러옵니다.
      if (auth.memberStatus == MemberLoadStatus.idle) {
        WidgetsBinding.instance.addPostFrameCallback((_) => auth.loadMember());
      }
      return MovieDetailScaffold(
        body: Center(
          child: auth.memberStatus == MemberLoadStatus.error
              ? MovieLogButton(
                  label: '내 정보 다시 조회',
                  onPressed: () => auth.loadMember(force: true),
                )
              : const CircularProgressIndicator(),
        ),
      );
    }

    final sessionVersion = auth.sessionVersion;
    return ChangeNotifierProvider<FavoriteDetailViewModel>(
      key: ValueKey('${member.email}:${guard.generation}'),
      create: (context) => FavoriteDetailViewModel(
        movieId: movieId,
        favoriteApi: context.read<FavoriteApiService>(),
        sessionGuard: guard,
        accountId: member.email,
        // 이 ViewModel을 만든 세션의 버전입니다. 이전 계정의 늦은 401은 무시됩니다.
        onSessionExpired: () =>
            auth.expireSession(sessionVersion: sessionVersion),
      ),
      child: child,
    );
  }
}
