import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../core/session/session_guard.dart';
import '../core/utils/safe_notify.dart';
import '../data/services/favorite_api_service.dart';

/// 영화 상세의 북마크(즐겨찾기) 상태입니다.
///
/// - [isLoading]: 첫 여부 조회 중 · [isSaving]: 등록·해제 중
/// - [isFavorite]: 서버에서 확인한 값 (optimistic update를 쓰지 않습니다)
/// - 응답을 반영하기 전에 [SessionGuard]로 "지금 세션의 응답인지"를 확인합니다.
class FavoriteDetailViewModel extends ChangeNotifier with SafeNotify {
  FavoriteDetailViewModel({
    required this.movieId,
    required this.favoriteApi,
    required this.sessionGuard,
    required this.accountId,
    this.onSessionExpired,
  });

  /// 상세 화면의 TMDB 영화 ID입니다. 경로에 favoriteId가 아니라 이 값을 씁니다.
  final int movieId;
  final FavoriteApiService favoriteApi;
  final SessionGuard sessionGuard;
  final String accountId;

  /// AUTH401_2/3/4·MEMBER404_1을 받았을 때 현재 세션을 정리합니다.
  /// 이 ViewModel을 만든 세션의 버전으로 묶여 있어, 이전 계정의 늦은 401은 무시됩니다.
  final Future<void> Function()? onSessionExpired;

  bool isFavorite = false;
  bool hasLoadedStatus = false;
  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;

  ({int generation, bool ok}) _snapshot() {
    final generation = sessionGuard.generation;
    return (
      generation: generation,
      ok: sessionGuard.isCurrent(generation, accountId) && !isDisposed,
    );
  }

  bool _stale(int generation) =>
      !sessionGuard.isCurrent(generation, accountId) || isDisposed;

  /// 세션 만료라면 정리를 요청하고 true를 돌려줍니다. (화면은 Router가 /login으로 옮깁니다)
  Future<bool> _expiredSession(Object error) async {
    if (error is! DioException) return false;
    final code = apiErrorCode(error);
    if (!isSessionExpiredError(error) && code != 'MEMBER404_1') return false;
    await onSessionExpired?.call();
    return true;
  }

  /// 상세 진입 때 한 번 서버의 즐겨찾기 여부를 조회합니다. (build에서 부르지 않습니다)
  Future<void> load() async {
    if (isLoading || isSaving) return;
    final snap = _snapshot();
    if (!snap.ok) return;
    isLoading = true;
    errorMessage = null;
    notifyIfAlive();
    try {
      final result = await favoriteApi.checkFavorite(movieId: movieId);
      if (_stale(snap.generation)) return;
      isFavorite = result.isFavorite;
      hasLoadedStatus = true;
    } catch (error) {
      if (_stale(snap.generation)) return;
      if (await _expiredSession(error)) return;
      debugPrint('즐겨찾기 여부 조회 실패: ${error.runtimeType}');
      errorMessage = '즐겨찾기 여부를 확인하지 못했습니다.';
    } finally {
      if (!_stale(snap.generation)) {
        isLoading = false;
        notifyIfAlive();
      }
    }
  }

  /// 서버 성공을 확인한 뒤에 북마크를 바꿉니다. 요청 중에는 중복 탭을 막습니다.
  /// timeout이어도 같은 POST를 자동으로 다시 보내지 않습니다.
  Future<void> toggle() async {
    if (isSaving || isLoading || !hasLoadedStatus) return;
    final snap = _snapshot();
    if (!snap.ok) return;
    final before = isFavorite;
    isSaving = true;
    errorMessage = null;
    notifyIfAlive();
    try {
      if (before) {
        await favoriteApi.deleteFavorite(movieId: movieId);
      } else {
        await favoriteApi.addFavorite(movieId: movieId);
      }
      if (_stale(snap.generation)) return;
      isFavorite = !before;
    } catch (error) {
      if (_stale(snap.generation)) return;
      if (await _expiredSession(error)) return;
      final code = error is DioException ? apiErrorCode(error) : null;
      // 이미 등록(409)·이미 해제(404)면 POST/DELETE를 반복하지 않고 서버의 현재 여부로 맞춥니다.
      if (code == 'FAVORITE409_1' || code == 'FAVORITE404_1') {
        await _syncAfterConflict(snap.generation, before);
      } else {
        debugPrint('즐겨찾기 저장 실패: ${error.runtimeType}');
        isFavorite = before;
        errorMessage = before ? '즐겨찾기 해제에 실패했습니다.' : '즐겨찾기 등록에 실패했습니다.';
      }
    } finally {
      if (!_stale(snap.generation)) {
        isSaving = false;
        notifyIfAlive();
      }
    }
  }

  Future<void> _syncAfterConflict(int generation, bool before) async {
    try {
      final synced = await favoriteApi.checkFavorite(movieId: movieId);
      if (_stale(generation)) return;
      isFavorite = synced.isFavorite;
      errorMessage = null;
    } catch (error) {
      if (_stale(generation)) return;
      if (await _expiredSession(error)) return;
      isFavorite = before;
      errorMessage = '서버 상태를 다시 확인하지 못했습니다.';
    }
  }
}
