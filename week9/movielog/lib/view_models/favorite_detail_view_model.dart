import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../core/session/session_guard.dart';
import '../core/utils/safe_notify.dart';
import '../data/services/favorite_api_service.dart';
import 'auth_view_model.dart';

/// 영화 상세 북마크 상태
/// 상세 Route가 ValueKey(email:generation)로 만들어서 계정 바뀌면 새로 생김
/// optimistic update 안 함 → 서버 성공 확인한 뒤에만 아이콘 바꿈
class FavoriteDetailViewModel extends ChangeNotifier with SafeNotify {
  FavoriteDetailViewModel({
    required this.movieId,
    required this.favoriteApi,
    required this.sessionGuard,
    required this.accountId,
    required this._auth,
  });

  /// TMDB 영화 id (즐겨찾기 path엔 favoriteId 말고 이 값)
  final int movieId;
  final FavoriteApiService favoriteApi;
  final SessionGuard sessionGuard;

  /// GET me로 확인한 email
  final String accountId;
  final AuthViewModel _auth;

  /// 서버에서 확인한 값
  bool isFavorite = false;

  /// 첫 여부 조회 성공했는지 (실패면 버튼 대신 새로고침)
  bool hasLoadedStatus = false;

  /// 첫 여부 조회 중
  bool isLoading = false;

  /// 등록·해제 중 (버튼 비활성 + 인디케이터)
  bool isSaving = false;
  String? errorMessage;

  /// 요청 보낼 때 세션 번호 + 지금도 같은 세션인지 한 번에
  ({int generation, bool ok}) _snapshot() {
    final generation = sessionGuard.generation;
    return (
      generation: generation,
      ok: sessionGuard.isCurrent(generation, accountId) && !isDisposed,
    );
  }

  bool _isCurrent(int generation) =>
      sessionGuard.isCurrent(generation, accountId) && !isDisposed;

  /// 상세 진입 시 한 번 (build에서 안 부름)
  Future<void> load() async {
    if (isLoading || isSaving) return;
    final snap = _snapshot();
    if (!snap.ok) return;
    final authVersion = _auth.sessionVersion;
    isLoading = true;
    errorMessage = null;
    notifyIfAlive();
    try {
      final result = await favoriteApi.checkFavorite(movieId: movieId);
      if (!_isCurrent(snap.generation)) return;
      isFavorite = result.isFavorite;
      hasLoadedStatus = true;
    } on DioException catch (error) {
      if (!_isCurrent(snap.generation)) return;
      if (isSessionExpired(error)) {
        await _auth.expireSession(version: authVersion);
        return;
      }
      errorMessage = '즐겨찾기 여부를 확인하지 못했습니다.';
    } catch (_) {
      if (!_isCurrent(snap.generation)) return;
      errorMessage = '즐겨찾기 여부를 확인하지 못했습니다.';
    } finally {
      if (_isCurrent(snap.generation)) {
        isLoading = false;
        notifyIfAlive();
      }
    }
  }

  /// 북마크 탭: 요청 중엔 중복 탭 막고, 성공한 뒤에만 상태 바꿈
  Future<void> toggle() async {
    if (isSaving || isLoading || !hasLoadedStatus) return;
    final snap = _snapshot();
    if (!snap.ok) return;
    final authVersion = _auth.sessionVersion;
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
      if (!_isCurrent(snap.generation)) return;
      isFavorite = !before;
    } on DioException catch (error) {
      if (!_isCurrent(snap.generation)) return;
      if (isSessionExpired(error)) {
        await _auth.expireSession(version: authVersion);
        return;
      }
      if (needsFavoriteSync(error)) {
        // 이미 등록(409)/이미 해제(404): POST·DELETE 반복 안 하고 GET으로 맞춤
        // (timeout 뒤 서버엔 이미 반영됐을 수 있음)
        await _syncAfterConflict(snap.generation, before);
      } else {
        isFavorite = before;
        errorMessage = _failMessage(before);
      }
    } catch (_) {
      if (!_isCurrent(snap.generation)) return;
      isFavorite = before;
      errorMessage = _failMessage(before);
    } finally {
      if (_isCurrent(snap.generation)) {
        isSaving = false;
        notifyIfAlive();
      }
    }
  }

  Future<void> _syncAfterConflict(int generation, bool before) async {
    try {
      final synced = await favoriteApi.checkFavorite(movieId: movieId);
      if (!_isCurrent(generation)) return;
      isFavorite = synced.isFavorite;
      errorMessage = null;
    } catch (_) {
      if (!_isCurrent(generation)) return;
      isFavorite = before;
      errorMessage = '서버 상태를 다시 확인하지 못했습니다.';
    }
  }

  /// 평점 Dialog에서 즐겨찾기까지 저장한 뒤 서버 값으로 다시 맞춤 (Challenge)
  Future<void> refreshFromServer() async {
    if (isLoading || isSaving) return;
    hasLoadedStatus = false;
    await load();
  }

  String _failMessage(bool wasFavorite) => wasFavorite
      ? '즐겨찾기에서 삭제하지 못했습니다. 다시 시도해 주세요.'
      : '즐겨찾기에 추가하지 못했습니다. 다시 시도해 주세요.';
}
