import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../core/session/session_guard.dart';
import '../core/utils/map_bounded.dart';
import '../core/utils/safe_notify.dart';
import '../data/models/favorite_list_item.dart';
import '../data/services/favorite_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import 'load_phase.dart';

/// 내 즐겨찾기 화면의 상태입니다.
///
/// 세션 확인 → MovieLog 즐겨찾기 목록 조회 → movieId로 TMDB 영화 정보 보충(최대 5개씩) →
/// 상태 결정 순서로 진행합니다. TMDB 한 건 실패는 그 카드만 placeholder로 남깁니다.
class FavoritesViewModel extends ChangeNotifier with SafeNotify {
  FavoritesViewModel({
    required this.favoriteApi,
    required this.tmdbApi,
    required this.sessionGuard,
    required this.accountId,
    this.onSessionExpired,
    this.enrichmentConcurrency = 5,
  });

  final FavoriteApiService favoriteApi;
  final TmdbMovieService tmdbApi;
  final SessionGuard sessionGuard;
  final String accountId;
  final Future<void> Function()? onSessionExpired;
  final int enrichmentConcurrency;

  LoadPhase phase = LoadPhase.idle;
  List<FavoriteListItem> items = const [];
  String? errorMessage;
  int _refreshGeneration = 0;

  /// 카드 하나만 다시 조회 중인 movieId입니다.
  final Set<int> retryingMovieIds = {};

  bool _isCurrent(int sessionGeneration, int refreshGeneration) =>
      sessionGuard.isCurrent(sessionGeneration, accountId) &&
      refreshGeneration == _refreshGeneration &&
      !isDisposed;

  /// 즐겨찾기 목록을 다시 조회합니다. 상세에서 돌아왔을 때도 이 메서드로 갱신합니다.
  /// 이미 목록이 있으면 새 결과가 올 때까지 기존 카드를 유지합니다.
  Future<void> refresh() async {
    final sessionGeneration = sessionGuard.generation;
    if (!sessionGuard.isCurrent(sessionGeneration, accountId) || isDisposed) {
      return;
    }
    final refreshGeneration = ++_refreshGeneration;
    if (phase != LoadPhase.ready) phase = LoadPhase.loading;
    errorMessage = null;
    notifyIfAlive();
    try {
      final favorites = await favoriteApi.fetchMyFavorites();
      if (!_isCurrent(sessionGeneration, refreshGeneration)) return;
      // 최근에 등록한 영화가 위에 오도록 정렬합니다.
      final sorted = [...favorites]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final enriched = await mapBounded(sorted, enrichmentConcurrency, (
        favorite,
      ) async {
        try {
          final movie = await tmdbApi.fetchMovieDetail(favorite.movieId);
          return FavoriteListItem(favorite: favorite, movie: movie);
        } catch (error) {
          debugPrint('즐겨찾기 영화 정보 조회 실패: ${favorite.movieId}');
          return FavoriteListItem(
            favorite: favorite,
            errorMessage: '영화 정보를 불러오지 못했습니다.',
          );
        }
      });
      if (!_isCurrent(sessionGeneration, refreshGeneration)) return;
      items = enriched;
      retryingMovieIds.clear();
      phase = items.isEmpty ? LoadPhase.empty : LoadPhase.ready;
    } catch (error) {
      if (!_isCurrent(sessionGeneration, refreshGeneration)) return;
      if (error is DioException &&
          (isSessionExpiredError(error) ||
              apiErrorCode(error) == 'MEMBER404_1')) {
        await onSessionExpired?.call();
        return;
      }
      debugPrint('내 즐겨찾기 조회 실패: ${error.runtimeType}');
      items = const [];
      phase = LoadPhase.error;
      errorMessage = '즐겨찾기를 불러오지 못했습니다.';
    } finally {
      if (_isCurrent(sessionGeneration, refreshGeneration)) notifyIfAlive();
    }
  }

  /// 영화 정보를 못 가져온 카드 하나만 TMDB에 다시 요청합니다. 다른 카드는 그대로 둡니다.
  Future<void> retryMovie(int movieId) async {
    if (retryingMovieIds.contains(movieId) || isDisposed) return;
    final sessionGeneration = sessionGuard.generation;
    final refreshGeneration = _refreshGeneration;
    if (!_isCurrent(sessionGeneration, refreshGeneration)) return;
    retryingMovieIds.add(movieId);
    notifyIfAlive();
    try {
      final movie = await tmdbApi.fetchMovieDetail(movieId);
      if (!_isCurrent(sessionGeneration, refreshGeneration)) return;
      items = [
        for (final item in items)
          item.favorite.movieId == movieId
              ? FavoriteListItem(favorite: item.favorite, movie: movie)
              : item,
      ];
    } catch (_) {
      if (!_isCurrent(sessionGeneration, refreshGeneration)) return;
      debugPrint('즐겨찾기 영화 정보 재조회 실패: $movieId');
    } finally {
      if (_isCurrent(sessionGeneration, refreshGeneration)) {
        retryingMovieIds.remove(movieId);
        notifyIfAlive();
      }
    }
  }
}
