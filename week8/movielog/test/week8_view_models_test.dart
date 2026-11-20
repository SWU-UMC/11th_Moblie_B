import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/edit_profile_view_model.dart';
import 'package:movielog/view_models/load_status.dart';
import 'package:movielog/view_models/movie_detail_view_model.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/view_models/session_ratings.dart';
import 'package:movielog/view_models/submit_status.dart';

import 'support/fake_movie_log_services.dart';
import 'support/fake_tmdb_movie_service.dart';

class _Deps {
  _Deps({String? token}) : storage = FakeTokenStorage(token);

  final FakeTokenStorage storage;
  final authApi = FakeAuthApiService();
  final memberApi = FakeMemberApiService();
  final ratingApi = FakeRatingApiService();
  final sessionRatings = SessionRatings();

  late final auth = AuthViewModel(
    authApi,
    memberApi,
    storage,
    sessionRatings: sessionRatings,
  );

  /// 로그인까지 끝낸 상태
  Future<AuthViewModel> signedIn() async {
    await auth.login('movie@example.com', 'Password1!');
    await auth.loadMember();
    return auth;
  }
}

TmdbMovieDto _movie(int id) => TmdbMovieDto(
  id: id,
  title: '영화 $id',
  overview: '',
  posterPath: null,
  backdropPath: null,
  releaseDate: null,
  genreIds: const [],
  voteAverage: 7,
  popularity: 1,
);

void main() {
  group('authRedirect', () {
    test('확인 중·재시도는 Splash, 로그아웃은 공개 화면만, 로그인되면 홈', () {
      expect(authRedirect(AuthStatus.initializing, '/home'), '/start');
      expect(authRedirect(AuthStatus.initializing, '/start'), isNull);
      expect(authRedirect(AuthStatus.retryRequired, '/login'), '/start');
      expect(authRedirect(AuthStatus.signedOut, '/my'), '/login');
      expect(authRedirect(AuthStatus.signedOut, '/register'), isNull);
      expect(authRedirect(AuthStatus.authenticating, '/login'), isNull);
      expect(authRedirect(AuthStatus.signedIn, '/login'), '/home');
      expect(authRedirect(AuthStatus.signedIn, '/start'), '/home');
      expect(authRedirect(AuthStatus.signedIn, '/my/ratings'), isNull);
    });
  });

  group('AuthViewModel 세션 복원', () {
    test('토큰 없으면 GET me 없이 signedOut', () async {
      final deps = _Deps();
      await deps.auth.restoreSession();
      expect(deps.auth.status, AuthStatus.signedOut);
      expect(deps.memberApi.fetchCalls, 0);
    });

    test('토큰 있어도 GET me 성공한 뒤에만 signedIn', () async {
      final deps = _Deps(token: 'saved');
      deps.memberApi.fetchGate = Completer();
      final future = deps.auth.restoreSession();
      await Future<void>.delayed(Duration.zero);
      expect(deps.auth.status, AuthStatus.initializing); // 아직 확인 중

      deps.memberApi.fetchGate!.complete();
      await future;
      expect(deps.auth.status, AuthStatus.signedIn);
      expect(deps.auth.member?.nickname, '무비러버');
    });

    test('토큰 만료(AUTH401_4)면 토큰 지우고 signedOut + 만료 표시', () async {
      final deps = _Deps(token: 'expired');
      deps.memberApi.fetchError = fakeExpiredError('/v7/members/me');
      await deps.auth.restoreSession();
      expect(deps.auth.status, AuthStatus.signedOut);
      expect(deps.auth.sessionExpired, isTrue);
      expect(deps.storage.token, isNull);
    });

    test('네트워크 실패는 토큰 안 지우고 retryRequired → 재시도 성공', () async {
      final deps = _Deps(token: 'valid');
      deps.memberApi.fetchError = fakeHttpError('/v7/members/me');
      await deps.auth.restoreSession();
      expect(deps.auth.status, AuthStatus.retryRequired);
      expect(deps.storage.token, 'valid');
      expect(deps.storage.deleteCalls, 0);

      deps.memberApi.fetchError = null;
      await deps.auth.restoreSession();
      expect(deps.auth.status, AuthStatus.signedIn);
    });

    test('저장소 읽기 실패도 retryRequired (토큰 무효랑 구분)', () async {
      final deps = _Deps(token: 'x')..storage.failRead = true;
      await deps.auth.restoreSession();
      expect(deps.auth.status, AuthStatus.retryRequired);
      expect(deps.auth.message, '인증 저장소를 읽지 못했어요.');
    });
  });

  group('AuthViewModel 로그인·로그아웃', () {
    test('성공: 토큰 저장 → signedIn, 내 정보는 loadMember가 따로', () async {
      final deps = _Deps();
      await deps.auth.login('movie@example.com', 'Password1!');
      expect(deps.auth.status, AuthStatus.signedIn);
      expect(deps.storage.token, 'token-1');
      expect(deps.memberApi.fetchCalls, 0); // 로그인에서 GET me 중복 안 함

      await deps.auth.loadMember();
      await deps.auth.loadMember(); // 이미 있으면 다시 안 부름
      expect(deps.memberApi.fetchCalls, 1);
      expect(deps.auth.member?.email, 'movie@example.com');
    });

    test('비밀번호 틀림(AUTH401_1)은 Form 문구, 만료 표시 안 켬', () async {
      final deps = _Deps();
      await deps.auth.login('movie@example.com', 'wrong');
      expect(deps.auth.status, AuthStatus.signedOut);
      expect(deps.auth.message, '이메일 또는 비밀번호를 확인해 주세요.');
      expect(deps.auth.sessionExpired, isFalse);
    });

    test('네트워크 실패는 다른 문구', () async {
      final deps = _Deps();
      deps.authApi.error = fakeHttpError('/v7/auth/login');
      await deps.auth.login('movie@example.com', 'Password1!');
      expect(deps.auth.message, '로그인 요청에 실패했어요. 잠시 후 다시 시도해 주세요.');
    });

    test('로그인 중 다시 눌러도 요청은 한 번', () async {
      final deps = _Deps();
      deps.authApi.gate = Completer();
      final first = deps.auth.login('movie@example.com', 'Password1!');
      await deps.auth.login('movie@example.com', 'Password1!');
      deps.authApi.gate!.complete();
      await first;
      expect(deps.authApi.calls, hasLength(1));
    });

    test('로그아웃: 토큰·member·세션 평점 지우고 만료 Snackbar 표시는 안 켬', () async {
      final deps = _Deps();
      await deps.signedIn();
      deps.sessionRatings.add(fakeRating(1, 3));

      await deps.auth.logout();
      expect(deps.auth.status, AuthStatus.signedOut);
      expect(deps.auth.member, isNull);
      expect(deps.storage.token, isNull);
      expect(deps.sessionRatings.ratings, isEmpty);
      expect(deps.auth.sessionExpired, isFalse);
    });

    test('내 정보 네트워크 실패는 로그아웃 안 하고 error, 재시도 가능', () async {
      final deps = _Deps();
      await deps.auth.login('movie@example.com', 'Password1!');
      deps.memberApi.fetchError = fakeHttpError('/v7/members/me');
      await deps.auth.loadMember();
      expect(deps.auth.status, AuthStatus.signedIn);
      expect(deps.auth.memberStatus, MemberLoadStatus.error);

      deps.memberApi.fetchError = null;
      await deps.auth.loadMember(force: true);
      expect(deps.auth.memberStatus, MemberLoadStatus.success);
    });

    test('로그아웃 뒤 늦게 온 GET me 응답은 무시', () async {
      final deps = _Deps();
      await deps.auth.login('movie@example.com', 'Password1!');
      deps.memberApi.fetchGate = Completer();
      final loading = deps.auth.loadMember();
      await deps.auth.logout();
      deps.memberApi.fetchGate!.complete();
      await loading;
      expect(deps.auth.member, isNull);
      expect(deps.auth.status, AuthStatus.signedOut);
    });

    test('이전 세션의 늦은 401은 새 로그인 세션을 지우지 않음', () async {
      final deps = _Deps();
      await deps.signedIn();
      final oldVersion = deps.auth.sessionVersion;
      await deps.auth.logout();
      await deps.auth.login('movie@example.com', 'Password1!');

      await deps.auth.expireSession(version: oldVersion);
      expect(deps.auth.status, AuthStatus.signedIn);
      expect(deps.storage.token, isNotNull);
    });

    test('동시 401 여러 개여도 정리는 한 번', () async {
      final deps = _Deps();
      await deps.signedIn();
      final version = deps.auth.sessionVersion;
      await Future.wait([
        deps.auth.expireSession(version: version),
        deps.auth.expireSession(version: version),
      ]);
      expect(deps.storage.deleteCalls, 1);
      expect(deps.auth.sessionExpired, isTrue);
    });
  });

  group('EditProfileViewModel', () {
    Future<(EditProfileViewModel, _Deps)> make() async {
      final deps = _Deps();
      await deps.signedIn();
      return (EditProfileViewModel(deps.memberApi, deps.auth), deps);
    }

    test('2~12자 검사는 요청 전에', () async {
      final (viewModel, deps) = await make();
      expect(await viewModel.save('a'), isFalse);
      expect(viewModel.nicknameError, '닉네임은 2~12자로 입력해 주세요.');
      expect(deps.memberApi.updateCalls, isEmpty);
    });

    test('현재 닉네임과 같으면 요청 없이 완료 (자기 닉네임은 409 아님)', () async {
      final (viewModel, deps) = await make();
      expect(await viewModel.save(' 무비러버 '), isTrue);
      expect(deps.memberApi.updateCalls, isEmpty);
    });

    test('성공하면 AuthViewModel.member 교체 (GET me 다시 안 함)', () async {
      final (viewModel, deps) = await make();
      final fetchCalls = deps.memberApi.fetchCalls;
      expect(await viewModel.save('새닉네임'), isTrue);
      expect(deps.auth.member?.nickname, '새닉네임');
      expect(deps.memberApi.fetchCalls, fetchCalls);
    });

    test('MEMBER409_1은 입력칸 오류, 네트워크는 message (로그아웃 없음)', () async {
      final deps = _Deps();
      await deps.signedIn();
      final memberApi = FakeMemberApiService(takenNicknames: {'중복닉'});
      final viewModel = EditProfileViewModel(memberApi, deps.auth);

      expect(await viewModel.save('중복닉'), isFalse);
      expect(viewModel.nicknameError, '이미 사용 중인 닉네임이에요.');
      expect(viewModel.message, isNull);

      memberApi.updateError = fakeHttpError('/v7/members/me');
      expect(await viewModel.save('다른닉'), isFalse);
      expect(viewModel.nicknameError, isNull);
      expect(viewModel.message, '네트워크 상태를 확인하고 다시 시도해 주세요.');
      expect(deps.auth.status, AuthStatus.signedIn);
    });

    test('401이면 세션 정리 → signedOut + 만료 표시', () async {
      final (viewModel, deps) = await make();
      deps.memberApi.updateError = fakeExpiredError('/v7/members/me');
      expect(await viewModel.save('새닉네임'), isFalse);
      expect(deps.auth.status, AuthStatus.signedOut);
      expect(deps.auth.sessionExpired, isTrue);
    });

    test('바뀐 내용 있을 때만 hasChanges', () async {
      final (viewModel, _) = await make();
      expect(viewModel.hasChanges('무비러버'), isFalse);
      expect(viewModel.hasChanges('무비러버2'), isTrue);
    });
  });

  group('MovieDetailViewModel.createRating (v7)', () {
    Future<(MovieDetailViewModel, _Deps)> make() async {
      final deps = _Deps();
      await deps.signedIn();
      final viewModel = MovieDetailViewModel(
        FakeTmdbMovieService(),
        deps.ratingApi,
        movieId: 3,
        auth: deps.auth,
        sessionRatings: deps.sessionRatings,
        movie: _movie(3),
      );
      return (viewModel, deps);
    }

    test('body에 memberId 없이 TMDB id로 등록, result Rating을 세션에 추가', () async {
      final (viewModel, deps) = await make();
      expect(viewModel.canRate, isTrue);
      await viewModel.createRating(score: 4, comment: '좋다');

      expect(deps.ratingApi.createCalls.single, {
        'movieId': 3,
        'score': 4,
        'comment': '좋다',
      });
      expect(viewModel.submitStatus, SubmitStatus.success);
      expect(deps.sessionRatings.ratings.single.movieId, 3);
      expect(viewModel.myScore, 4);
      expect(viewModel.canRate, isFalse); // 같은 영화는 마이페이지에서 수정
    });

    test('409는 안내만 하고 로그인 유지', () async {
      final (viewModel, deps) = await make();
      deps.ratingApi.writeError = fakeCodeError(
        '/v7/ratings',
        409,
        'RATING409_1',
        '이미 이 영화에 평점을 남기셨습니다.',
      );
      await viewModel.createRating(score: 5);
      expect(viewModel.submitStatus, SubmitStatus.error);
      expect(viewModel.submitMessage, '이미 이 영화에 평점을 남겼어요.');
      expect(deps.auth.status, AuthStatus.signedIn);
    });

    test('401이면 세션 정리 (Router가 /login으로)', () async {
      final (viewModel, deps) = await make();
      deps.ratingApi.writeError = fakeExpiredError('/v7/ratings');
      await viewModel.createRating(score: 5);
      expect(deps.auth.status, AuthStatus.signedOut);
      expect(deps.auth.sessionExpired, isTrue);
    });

    test('응답 오기 전에 로그아웃하면 이전 응답 반영 안 함', () async {
      final (viewModel, deps) = await make();
      deps.ratingApi.writeGate = Completer();
      final future = viewModel.createRating(score: 4);
      await deps.auth.logout();
      deps.ratingApi.writeGate!.complete();
      await future;
      expect(deps.sessionRatings.ratings, isEmpty);
    });
  });

  group('MyRatingsViewModel (세션 평점)', () {
    Future<(MyRatingsViewModel, _Deps)> make() async {
      final deps = _Deps();
      await deps.signedIn();
      for (final id in [1, 2]) {
        final rating = await deps.ratingApi.createRating(
          CreateRatingRequest(movieId: id, score: 3),
        );
        deps.sessionRatings.add(rating);
      }
      final viewModel = MyRatingsViewModel(
        deps.ratingApi,
        FakeTmdbMovieService(),
        auth: deps.auth,
        sessionRatings: deps.sessionRatings,
      );
      await viewModel.load();
      return (viewModel, deps);
    }

    test('세션 평점 + TMDB 영화 정보, 최근 등록이 위', () async {
      final (viewModel, _) = await make();
      expect(viewModel.status, LoadStatus.success);
      expect(viewModel.ratings.map((e) => e.movie?.title), ['영화 2', '영화 1']);
    });

    test('수정 PATCH result로 교체 (GET 없음)', () async {
      final (viewModel, deps) = await make();
      final ratingId = viewModel.ratings.first.rating.ratingId;
      await viewModel.updateRating(ratingId: ratingId, score: 1, comment: '바꿈');
      expect(deps.ratingApi.updateCalls.single.$2, {
        'score': 1,
        'comment': '바꿈',
      });
      expect(viewModel.ratings.first.rating.score, 1);
      expect(viewModel.ratings.first.rating.comment, '바꿈');
    });

    test('삭제 성공 → 세션에서 빠지고 마지막이면 Empty', () async {
      final (viewModel, deps) = await make();
      for (final entry in List.of(viewModel.ratings)) {
        await viewModel.deleteRating(entry.rating.ratingId);
      }
      expect(viewModel.status, LoadStatus.empty);
      expect(deps.sessionRatings.ratings, isEmpty);
    });

    test('403은 SubmitFailure, 404(이미 없음)는 목록에서도 뺌', () async {
      final (viewModel, deps) = await make();
      final first = viewModel.ratings.first.rating.ratingId;
      deps.ratingApi.failDeleteIds = {first};
      await expectLater(
        viewModel.deleteRating(first),
        throwsA(isA<SubmitFailure>()),
      );
      expect(viewModel.ratings, hasLength(2));

      final second = viewModel.ratings.last.rating.ratingId;
      deps.ratingApi.server.remove(second); // 서버엔 이미 없음
      await expectLater(
        viewModel.deleteRating(second),
        throwsA(isA<SubmitFailure>()),
      );
      expect(viewModel.ratings, hasLength(1));
    });

    test('401이면 세션 정리하고 목록도 비움', () async {
      final (viewModel, deps) = await make();
      deps.ratingApi.writeError = fakeExpiredError('/v7/ratings/1');
      await expectLater(
        viewModel.deleteRating(viewModel.ratings.first.rating.ratingId),
        throwsA(isA<SubmitFailure>()),
      );
      expect(deps.auth.status, AuthStatus.signedOut);
      expect(deps.sessionRatings.ratings, isEmpty);
    });

    test('다중 삭제: 일부 실패면 실패한 것만 선택 유지', () async {
      final (viewModel, deps) = await make();
      viewModel.startEditing();
      for (final entry in viewModel.ratings) {
        viewModel.toggleSelected(entry.rating.ratingId);
      }
      final failing = viewModel.ratings.first.rating.ratingId;
      deps.ratingApi.failDeleteIds = {failing};
      final failed = await viewModel.deleteSelectedRatings();
      expect(failed, 1);
      expect(viewModel.selectedRatingIds, {failing});
      expect(viewModel.ratings, hasLength(1));
      expect(viewModel.isEditing, isTrue);
    });
  });
}
