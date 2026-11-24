import 'package:flutter/foundation.dart';

import '../core/utils/safe_notify.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/models/tmdb_movie_page_dto.dart';
import '../data/services/tmdb_movie_service.dart';
import 'load_phase.dart';

/// 조회 조건: 장르(여러 개 OR) 또는 검색어
/// query 있으면 Search, 없으면 Discover
typedef MovieQuery = ({List<int> genreIds, String query});

/// 한 page씩 불러오는 영화 목록 (영화 목록 화면 / 검색 화면이 각자 인스턴스)
/// 5주차 "Discover 최대 30개 한 번에" 대신 더 보기·무한 스크롤로 page 추가
class PagedMoviesViewModel extends ChangeNotifier with SafeNotify {
  PagedMoviesViewModel({required this.tmdbApi});

  final TmdbMovieService tmdbApi;

  /// TMDB page는 1~500까지만 요청 가능
  static const maxTmdbPage = 500;

  LoadPhase phase = LoadPhase.idle;
  final List<TmdbMovieDto> _movies = [];

  /// 다음에 요청할 page (실패하면 그대로 → 같은 page 재시도)
  int nextPage = 1;

  /// total_pages와 500 중 작은 값
  int totalPages = 1;

  /// 다음 page 요청 중 (기존 카드는 그대로)
  bool isLoadingMore = false;

  /// 첫 page 실패 문구
  String? errorMessage;

  /// 다음 page 실패 문구 (목록 안 지우고 하단에만)
  String? loadMoreError;

  int _requestGeneration = 0;
  MovieQuery _condition = (genreIds: const [], query: '');

  List<TmdbMovieDto> get movies => List.unmodifiable(_movies);
  bool get hasMore => nextPage <= totalPages;
  MovieQuery get condition => _condition;

  /// 조건 바뀜(장르·검색어·새로고침) → 목록·page·추가 로딩 상태 다 초기화 후 page 1
  /// generation 올려서 이전 조건의 늦은 응답은 무시
  Future<void> loadInitial({
    List<int> genreIds = const [],
    String query = '',
  }) async {
    if (isDisposed) return;
    _condition = (genreIds: List.unmodifiable(genreIds), query: query.trim());
    final generation = ++_requestGeneration;
    final condition = _condition;
    phase = LoadPhase.loading;
    errorMessage = null;
    loadMoreError = null;
    isLoadingMore = false;
    _movies.clear();
    nextPage = 1;
    totalPages = 1;
    notifyIfAlive();

    try {
      final page = await _fetchPage(1, condition);
      if (_isStale(generation)) return;
      _applyFirstPage(page);
    } catch (error) {
      if (_isStale(generation)) return;
      debugPrint('영화 첫 page 실패: $error');
      phase = LoadPhase.error;
      errorMessage = condition.query.isEmpty
          ? '영화 목록을 불러오지 못했습니다.'
          : '검색 결과를 불러오지 못했습니다.';
    } finally {
      if (!_isStale(generation)) notifyIfAlive();
    }
  }

  /// 같은 조건으로 page 1부터 다시 (당겨서 새로고침, 첫 page 재시도)
  Future<void> refresh() =>
      loadInitial(genreIds: _condition.genreIds, query: _condition.query);

  /// 더 보기 / 무한 스크롤 / 다음 page 재시도
  /// 실패해도 nextPage 안 올려서 같은 page 다시 요청
  Future<void> loadNextPage() async {
    if (isDisposed || isLoadingMore || !hasMore || phase != LoadPhase.ready) {
      return;
    }
    final generation = _requestGeneration;
    final pageToLoad = nextPage;
    final condition = _condition;
    isLoadingMore = true;
    loadMoreError = null;
    notifyIfAlive();

    try {
      final page = await _fetchPage(pageToLoad, condition);
      if (_isStale(generation)) return;
      _appendPage(page);
    } catch (error) {
      if (_isStale(generation)) return;
      debugPrint('영화 $pageToLoad page 실패: $error');
      loadMoreError = '추가 영화 조회에 실패했습니다.';
    } finally {
      if (!_isStale(generation)) {
        isLoadingMore = false;
        notifyIfAlive();
      }
    }
  }

  Future<TmdbMoviePageDto> _fetchPage(int page, MovieQuery condition) async {
    final result = condition.query.isNotEmpty
        ? await tmdbApi.searchMovies(page: page, query: condition.query)
        : await tmdbApi.discoverMovies(
            page: page,
            genreIds: condition.genreIds,
          );
    // 요청한 page랑 응답 page 다르면 이어 붙이면 안 됨
    if (result.page != page || result.totalPages < 0) {
      throw const FormatException('TMDB page 정보가 요청이랑 다름');
    }
    return result;
  }

  void _applyFirstPage(TmdbMoviePageDto page) {
    _movies
      ..clear()
      ..addAll(_dedupe(page.results));
    _updatePaging(page);
    phase = _movies.isEmpty ? LoadPhase.empty : LoadPhase.ready;
  }

  void _appendPage(TmdbMoviePageDto page) {
    _movies.addAll(_dedupe(page.results));
    _updatePaging(page);
  }

  /// 성공한 응답 반영할 때만 page + 1
  void _updatePaging(TmdbMoviePageDto page) {
    totalPages = page.totalPages > maxTmdbPage ? maxTmdbPage : page.totalPages;
    nextPage = page.page + 1;
  }

  /// TMDB는 page 바뀌어도 같은 영화가 또 올 수 있음 → id Set으로 중복 제외
  List<TmdbMovieDto> _dedupe(List<TmdbMovieDto> incoming) {
    final seen = _movies.map((movie) => movie.id).toSet();
    return incoming.where((movie) => seen.add(movie.id)).toList();
  }

  bool _isStale(int generation) =>
      isDisposed || generation != _requestGeneration;
}
