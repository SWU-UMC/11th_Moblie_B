import 'package:flutter/foundation.dart';

import '../core/utils/safe_notify.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/models/tmdb_movie_page.dart';
import '../data/services/tmdb_movie_service.dart';
import 'load_phase.dart';

/// TMDB Discover/Search를 "더 보기"로 한 page씩 불러옵니다.
/// 영화 목록과 검색 화면이 각자 별도 인스턴스를 씁니다.
///
/// - 첫 page: 기존 목록을 비우고 [phase]로 로딩/빈 결과/오류를 구분합니다.
/// - 다음 page: 목록을 유지한 채 [isLoadingMore]·[loadMoreError]로 구분하고,
///   실패하면 [nextPage]를 올리지 않아 같은 page를 다시 요청합니다.
/// - 장르·검색어가 바뀌면 [_requestGeneration]을 올려 이전 조건의 늦은 응답을 버립니다.
class PagedMoviesViewModel extends ChangeNotifier with SafeNotify {
  PagedMoviesViewModel({required this.tmdbApi});

  final TmdbMovieService tmdbApi;

  /// TMDB가 허용하는 최대 page입니다. total_pages가 더 커도 501은 요청하지 않습니다.
  static const maxTmdbPage = 500;

  LoadPhase phase = LoadPhase.idle;
  final List<TmdbMovieDto> movies = [];
  int nextPage = 1;
  int totalPages = 1;
  bool isLoadingMore = false;
  String? errorMessage;
  String? loadMoreError;

  int _requestGeneration = 0;
  ({int? genreId, String query}) _condition = (genreId: null, query: '');

  bool get hasMore => nextPage <= totalPages;
  int? get genreId => _condition.genreId;
  String get query => _condition.query;

  /// 새 조건의 첫 page를 요청합니다. 재시도·refresh도 이 메서드를 씁니다.
  Future<void> loadInitial({int? genreId, String query = ''}) async {
    if (isDisposed) return;
    _condition = (genreId: genreId, query: query.trim());
    final generation = ++_requestGeneration;
    phase = LoadPhase.loading;
    errorMessage = null;
    loadMoreError = null;
    isLoadingMore = false;
    movies.clear();
    nextPage = 1;
    totalPages = 1;
    notifyIfAlive();
    try {
      final page = await _fetchPage(1, _condition);
      if (generation != _requestGeneration || isDisposed) return;
      _applyFirstPage(page);
    } catch (error) {
      if (generation != _requestGeneration || isDisposed) return;
      debugPrint('첫 page 조회 실패: ${error.runtimeType}');
      phase = LoadPhase.error;
      errorMessage = _condition.query.isEmpty
          ? '영화 목록을 불러오지 못했습니다.'
          : '검색 결과를 불러오지 못했습니다.';
    } finally {
      if (generation == _requestGeneration && !isDisposed) notifyIfAlive();
    }
  }

  /// 다음 page를 아래에 이어 붙입니다. 실패해도 nextPage를 올리지 않습니다.
  Future<void> loadNextPage() async {
    if (isDisposed || isLoadingMore || !hasMore || phase != LoadPhase.ready) {
      return;
    }
    final generation = _requestGeneration;
    final pageToLoad = nextPage;
    isLoadingMore = true;
    loadMoreError = null;
    notifyIfAlive();
    try {
      final page = await _fetchPage(pageToLoad, _condition);
      if (generation != _requestGeneration || isDisposed) return;
      _appendPage(page);
    } catch (error) {
      if (generation != _requestGeneration || isDisposed) return;
      debugPrint('page $pageToLoad 조회 실패: ${error.runtimeType}');
      loadMoreError = '추가 영화 조회에 실패했습니다.';
    } finally {
      if (generation == _requestGeneration && !isDisposed) {
        isLoadingMore = false;
        notifyIfAlive();
      }
    }
  }

  Future<TmdbMoviePageDto> _fetchPage(
    int page,
    ({int? genreId, String query}) condition,
  ) async {
    final result = condition.query.isNotEmpty
        ? await tmdbApi.searchMovies(page: page, query: condition.query)
        : await tmdbApi.discoverMovies(page: page, genreId: condition.genreId);
    // 요청한 page와 응답 page가 다르면 순서가 섞일 수 있으므로 실패로 봅니다.
    if (result.page != page || result.page < 1 || result.totalPages < 0) {
      throw const FormatException('TMDB page metadata is inconsistent.');
    }
    return result;
  }

  void _applyFirstPage(TmdbMoviePageDto page) {
    movies
      ..clear()
      ..addAll(_dedupe(page.results));
    _applyPageMeta(page);
    phase = movies.isEmpty ? LoadPhase.empty : LoadPhase.ready;
  }

  void _appendPage(TmdbMoviePageDto page) {
    movies.addAll(_dedupe(page.results));
    _applyPageMeta(page);
  }

  void _applyPageMeta(TmdbMoviePageDto page) {
    totalPages = page.totalPages > maxTmdbPage ? maxTmdbPage : page.totalPages;
    nextPage = page.page + 1;
  }

  /// 이미 보이는 movieId는 제외합니다. (page 사이에 순위가 바뀌면 같은 영화가 다시 옵니다)
  List<TmdbMovieDto> _dedupe(List<TmdbMovieDto> incoming) {
    final seen = movies.map((movie) => movie.id).toSet();
    return incoming
        .where((movie) => seen.add(movie.id))
        .toList(growable: false);
  }
}
