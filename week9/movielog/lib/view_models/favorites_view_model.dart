import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../core/session/session_guard.dart';
import '../core/utils/map_bounded.dart';
import '../core/utils/safe_notify.dart';
import '../data/models/favorite_list_item.dart';
import '../data/models/favorite_response_dto.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/favorite_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import 'auth_view_model.dart';
import 'load_phase.dart';

/// 내 즐겨찾기 (/my/favorites)
/// 목록은 MovieLog(JWT), 제목·포스터는 movieId로 TMDB에서 보충
/// Route가 ValueKey(email:generation)로 만들어서 계정 바뀌면 이전 목록 버림
class FavoritesViewModel extends ChangeNotifier with SafeNotify {
  FavoritesViewModel({
    required this.favoriteApi,
    required this.tmdbApi,
    required this.sessionGuard,
    required this.accountId,
    required this._auth,
    this.enrichmentConcurrency = 5,
  });

  final FavoriteApiService favoriteApi;
  final TmdbMovieService tmdbApi;
  final SessionGuard sessionGuard;
  final String accountId;
  final AuthViewModel _auth;

  /// TMDB 보충 요청 동시 개수
  final int enrichmentConcurrency;

  LoadPhase phase = LoadPhase.idle;
  List<FavoriteListItem> items = const [];
  String? errorMessage;

  /// 목록 있는 상태에서 다시 조회 중 (상세 갔다 돌아왔을 때 등)
  /// → 전체 로딩으로 안 바꾸고 기존 카드 유지
  bool isRefreshing = false;

  /// TMDB 공개 영화 정보 캐시 (movieId → 영화)
  /// 사용자별 즐겨찾기 상태랑 섞지 않음 → 계정 바뀌어도 공개 정보라 문제없음
  final Map<int, TmdbMovieDto> _movieById = {};

  int _refreshGeneration = 0;

  bool _isCurrent(int sessionGeneration, int refreshGeneration) =>
      sessionGuard.isCurrent(sessionGeneration, accountId) &&
      refreshGeneration == _refreshGeneration &&
      !isDisposed;

  /// 세션 확인 → 목록 조회 → TMDB 보충(최대 5개씩) → 상태 결정
  Future<void> refresh() async {
    final sessionGeneration = sessionGuard.generation;
    if (!sessionGuard.isCurrent(sessionGeneration, accountId) || isDisposed) {
      return;
    }
    final authVersion = _auth.sessionVersion;
    final refreshGeneration = ++_refreshGeneration;
    if (items.isEmpty) {
      phase = LoadPhase.loading;
    } else {
      isRefreshing = true;
    }
    errorMessage = null;
    notifyIfAlive();

    try {
      final favorites = await favoriteApi.fetchMyFavorites();
      if (!_isCurrent(sessionGeneration, refreshGeneration)) return;
      final enriched = await mapBounded(
        favorites,
        enrichmentConcurrency,
        _enrich,
      );
      if (!_isCurrent(sessionGeneration, refreshGeneration)) return;
      items = enriched;
      phase = items.isEmpty ? LoadPhase.empty : LoadPhase.ready;
    } on DioException catch (error) {
      if (!_isCurrent(sessionGeneration, refreshGeneration)) return;
      if (isSessionExpired(error)) {
        await _auth.expireSession(version: authVersion);
        return;
      }
      _applyListFailure();
    } catch (_) {
      if (!_isCurrent(sessionGeneration, refreshGeneration)) return;
      _applyListFailure();
    } finally {
      if (_isCurrent(sessionGeneration, refreshGeneration)) {
        isRefreshing = false;
        notifyIfAlive();
      }
    }
  }

  /// 목록 자체 실패: 처음이면 Error 화면, 이미 카드 있으면 유지하고 안내만
  void _applyListFailure() {
    if (items.isEmpty) {
      phase = LoadPhase.error;
      errorMessage = '즐겨찾기를 불러오지 못했습니다.';
    } else {
      errorMessage = '목록을 새로 불러오지 못했습니다. 이전 목록을 보여줍니다.';
    }
  }

  /// 카드 하나 보충: 실패해도 throw 안 하고 그 카드만 placeholder
  /// (Future.wait 안에서 하나 실패하면 전체 실패되는 것 방지)
  Future<FavoriteListItem> _enrich(FavoriteResponseDto favorite) async {
    final cached = _movieById[favorite.movieId];
    if (cached != null) {
      return FavoriteListItem(favorite: favorite, movie: cached);
    }
    try {
      final movie = await tmdbApi.fetchMovieDetail(favorite.movieId);
      _movieById[favorite.movieId] = movie;
      return FavoriteListItem(favorite: favorite, movie: movie);
    } catch (_) {
      return FavoriteListItem(
        favorite: favorite,
        errorMessage: '영화 정보를 불러오지 못했습니다.',
      );
    }
  }

  /// placeholder 카드의 "정보 다시 불러오기": 그 카드만 TMDB 재조회
  Future<void> retryMovie(int favoriteId) async {
    final index = items.indexWhere((i) => i.favorite.favoriteId == favoriteId);
    if (index < 0 || items[index].hasMovie || items[index].isRetrying) return;
    final sessionGeneration = sessionGuard.generation;
    if (!sessionGuard.isCurrent(sessionGeneration, accountId) || isDisposed) {
      return;
    }
    final refreshGeneration = _refreshGeneration;
    final favorite = items[index].favorite;
    _replaceItem(
      favoriteId,
      FavoriteListItem(favorite: favorite, isRetrying: true),
    );
    notifyIfAlive();

    final updated = await _enrich(favorite);
    // 그 사이 목록 전체를 다시 불렀거나 계정 바뀌었으면 버림
    if (!_isCurrent(sessionGeneration, refreshGeneration)) return;
    _replaceItem(favoriteId, updated);
    notifyIfAlive();
  }

  void _replaceItem(int favoriteId, FavoriteListItem item) {
    items = [
      for (final current in items)
        current.favorite.favoriteId == favoriteId ? item : current,
    ];
  }
}
