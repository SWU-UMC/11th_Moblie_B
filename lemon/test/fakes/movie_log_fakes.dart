import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/core/storage/token_storage.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/login_models.dart';
import 'package:movielog/data/models/member_info.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/models/sign_up_models.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page.dart';
import 'package:movielog/data/services/auth_api_service.dart';
import 'package:movielog/data/services/member_api_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/sign_up_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/main.dart';
import 'package:movielog/view_models/session_ratings_view_model.dart';
import 'package:provider/provider.dart';

DioException fakeDioError(String path, {int? statusCode, Object? data}) =>
    DioException(
      requestOptions: RequestOptions(path: path),
      response: statusCode == null
          ? null
          : Response(
              requestOptions: RequestOptions(path: path),
              statusCode: statusCode,
              data: data,
            ),
      message: 'fake error',
    );

/// 공통 형식의 오류 응답입니다.
DioException fakeCommonError(
  String path,
  int statusCode,
  String code,
  String message,
) => fakeDioError(
  path,
  statusCode: statusCode,
  data: {'isSuccess': false, 'code': code, 'message': message, 'result': null},
);

/// 보호 요청의 토큰 무효(AUTH401_3)입니다.
DioException fakeInvalidToken(String path) =>
    fakeCommonError(path, 401, 'AUTH401_3', '유효하지 않은 토큰입니다.');

/// 실제 secure storage 대신 쓰는 메모리 저장소입니다.
class InMemoryTokenStorage implements TokenStorage {
  InMemoryTokenStorage([this.token]);

  String? token;

  /// 값을 넣으면 읽기·쓰기·삭제가 모두 실패합니다. (저장소 오류 확인용)
  bool fail = false;
  final log = <String>[];

  @override
  Future<String?> readAccessToken() async {
    log.add('read');
    if (fail) throw StateError('storage');
    return token;
  }

  @override
  Future<void> saveAccessToken(String value) async {
    log.add('save');
    if (fail) throw StateError('storage');
    token = value;
  }

  @override
  Future<void> deleteAccessToken() async {
    log.add('delete');
    if (fail) throw StateError('storage');
    token = null;
  }
}

final fakeMember = MemberInfo(
  email: 'movie@example.com',
  nickname: '무비러버',
  createdAt: DateTime.utc(2026, 11, 1),
);

/// 로그인 결과를 테스트에서 정하는 Service입니다. 기본은 성공입니다.
class FakeAuthApiService extends AuthApiService {
  FakeAuthApiService({this.onLogin}) : super(Dio());

  Future<LoginResult> Function(LoginRequest request)? onLogin;
  final requests = <LoginRequest>[];

  @override
  Future<LoginResult> login(LoginRequest request) async {
    requests.add(request);
    final handler = onLogin;
    if (handler != null) return handler(request);
    return const LoginResult(nickname: '무비러버', accessToken: 'fresh-token');
  }
}

/// GET/PATCH me 결과를 테스트에서 정하는 Service입니다. 기본은 [fakeMember]로 성공합니다.
class FakeMemberApiService extends MemberApiService {
  FakeMemberApiService({this.onFetch, this.onUpdate}) : super(Dio());

  Future<MemberInfo> Function()? onFetch;
  Future<MemberInfo> Function(String nickname)? onUpdate;
  int fetchCount = 0;
  final updates = <String>[];

  @override
  Future<MemberInfo> fetchMe() async {
    fetchCount++;
    final handler = onFetch;
    if (handler != null) return handler();
    return fakeMember;
  }

  @override
  Future<MemberInfo> updateNickname(String nickname) async {
    updates.add(nickname);
    final handler = onUpdate;
    if (handler != null) return handler(nickname);
    return MemberInfo(
      email: fakeMember.email,
      nickname: nickname,
      createdAt: fakeMember.createdAt,
    );
  }
}

/// 실제 서버 대신 [taken]에 든 값만 "중복"으로 답하는 회원가입 Service입니다.
class FakeSignUpService extends SignUpService {
  FakeSignUpService({
    this.taken = const {},
    this.fail = false,
    this.onSignUp,
    this.memberId = 42,
  }) : super(Dio());

  final Set<String> taken;
  bool fail;

  /// 값을 넣으면 [gate]가 완료될 때까지 응답을 미룹니다. (통신 중 상태 확인용)
  Completer<void>? gate;

  /// 가입 요청을 직접 처리합니다. 없으면 [memberId]로 성공합니다.
  Future<CommonResponse<SignUpResult>> Function(CreateMemberRequest request)?
  onSignUp;
  final int memberId;

  final nicknameCalls = <String>[];
  final emailCalls = <String>[];
  final signUpCalls = <CreateMemberRequest>[];

  @override
  Future<bool> checkNickname(String nickname) {
    nicknameCalls.add(nickname);
    return _answer(nickname);
  }

  @override
  Future<bool> checkEmail(String email) {
    emailCalls.add(email);
    return _answer(email);
  }

  @override
  Future<CommonResponse<SignUpResult>> signUp(
    CreateMemberRequest request,
  ) async {
    signUpCalls.add(request);
    final handler = onSignUp;
    if (handler != null) return handler(request);
    return CommonResponse(
      isSuccess: true,
      code: 'COMMON201',
      message: '회원가입에 성공했습니다.',
      result: SignUpResult(
        memberId: memberId,
        email: request.email.trim(),
        nickname: request.nickname.trim(),
      ),
    );
  }

  Future<bool> _answer(String value) async {
    final waitFor = gate;
    if (waitFor != null) await waitFor.future;
    if (fail) throw fakeDioError('/v7/members');
    return !taken.contains(value.trim());
  }
}

/// 평점 쓰기 결과를 테스트에서 정하는 Service입니다.
/// handler가 없으면 서버처럼 Rating 객체를 만들어 성공으로 돌려줍니다.
class FakeRatingApiService extends RatingApiService {
  FakeRatingApiService({this.onCreate, this.onUpdate, this.onDelete})
    : super(Dio(), Dio());

  Future<RatingDto> Function(CreateRatingRequest request)? onCreate;
  Future<RatingDto> Function(int ratingId, int score, String? comment)?
  onUpdate;
  Future<void> Function(int ratingId)? onDelete;

  int _nextId = 100;

  /// 이 Service로 등록한 평점입니다. 수정 응답의 movieId를 서버처럼 유지하는 데 씁니다.
  final server = <int, RatingDto>{};
  final creates = <CreateRatingRequest>[];
  final updates = <(int ratingId, int score, String? comment)>[];
  final deletes = <int>[];

  /// 순서 확인용 호출 기록입니다. (예: ['POST', 'PATCH 100'])
  final log = <String>[];

  @override
  Future<RatingDto> createRating(CreateRatingRequest request) async {
    creates.add(request);
    log.add('POST');
    final handler = onCreate;
    if (handler != null) return handler(request);
    final comment = request.comment?.trim();
    // seedSessionRatings로 넣은 id와 겹치지 않도록 비어 있는 id까지 넘깁니다.
    while (server.containsKey(_nextId)) {
      _nextId++;
    }
    final rating = fakeRating(
      _nextId++,
      request.movieId,
      request.score,
      comment: comment == null || comment.isEmpty ? null : comment,
    );
    return server[rating.ratingId] = rating;
  }

  @override
  Future<RatingDto> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    updates.add((ratingId, score, comment));
    log.add('PATCH $ratingId');
    final handler = onUpdate;
    if (handler != null) return handler(ratingId, score, comment);
    return server[ratingId] = RatingDto(
      ratingId: ratingId,
      movieId: server[ratingId]?.movieId ?? 0,
      score: score,
      comment: comment,
      createdAt: DateTime.utc(2026, 11, 1, 3),
      updatedAt: DateTime.utc(2026, 11, 2, 3),
    );
  }

  @override
  Future<void> deleteRating(int ratingId) async {
    deletes.add(ratingId);
    log.add('DELETE $ratingId');
    await onDelete?.call(ratingId);
    server.remove(ratingId);
  }
}

/// movieId로 영화를 찾는 부분만 바꾼 TMDB Service입니다.
/// [movies]에 없는 id는 404(null), [failingIds]는 네트워크 오류로 답합니다.
class FakeMovieLookupService extends TmdbMovieService {
  FakeMovieLookupService({this.movies = const {}, this.failingIds = const {}})
    : super(Dio());

  final Map<int, TmdbMovieDto> movies;
  Set<int> failingIds;
  final lookups = <int>[];

  @override
  Future<TmdbMovieDto> fetchMovieDetail(int movieId) async {
    lookups.add(movieId);
    if (failingIds.contains(movieId)) throw fakeDioError('/movie/$movieId');
    final movie = movies[movieId];
    if (movie == null) throw fakeDioError('/movie/$movieId', statusCode: 404);
    return movie;
  }

  @override
  Future<TmdbMoviePageDto> fetchPopular({int page = 1}) async =>
      const TmdbMoviePageDto(
        page: 1,
        results: [],
        totalPages: 1,
        totalResults: 0,
      );
}

RatingDto fakeRating(int ratingId, int movieId, int score, {String? comment}) =>
    RatingDto(
      ratingId: ratingId,
      movieId: movieId,
      score: score,
      comment: comment,
      createdAt: DateTime.utc(2026, 11, 1, 3),
      updatedAt: DateTime.utc(2026, 11, 1, 3),
    );

TmdbMovieDto fakeMovie(int id, String title) => TmdbMovieDto(
  id: id,
  title: title,
  overview: '',
  posterPath: null,
  backdropPath: null,
  releaseDate: null,
  genreIds: const [],
  voteAverage: 0,
  popularity: 0,
);

/// 테스트용 앱입니다. [token]이 있으면 앱 시작 때 GET me 검증을 거쳐 [initialLocation]으로
/// 들어가고, 없으면 로그인 화면에서 시작합니다.
class TestApp {
  TestApp({
    String? token = 'saved-token',
    TmdbMovieService? movieService,
    FakeSignUpService? signUpService,
    FakeAuthApiService? authApi,
    FakeMemberApiService? memberApi,
    FakeRatingApiService? ratingApi,
  }) : storage = InMemoryTokenStorage(token),
       movieService = movieService ?? FakeMovieLookupService(),
       signUpService = signUpService ?? FakeSignUpService(),
       authApi = authApi ?? FakeAuthApiService(),
       memberApi = memberApi ?? FakeMemberApiService(),
       ratingApi = ratingApi ?? FakeRatingApiService();

  final InMemoryTokenStorage storage;
  final TmdbMovieService movieService;
  final FakeSignUpService signUpService;
  final FakeAuthApiService authApi;
  final FakeMemberApiService memberApi;
  final FakeRatingApiService ratingApi;
  late GoRouter router;

  Widget build({String initialLocation = '/start'}) => MovieLogApp(
    initialLocation: initialLocation,
    tokenStorage: storage,
    movieService: movieService,
    signUpService: signUpService,
    authApiService: authApi,
    memberApiService: memberApi,
    ratingApiService: ratingApi,
    onRouterCreated: (value) => router = value,
  );

  String get location => router.state.uri.toString();
}

/// 로그인 세션에 평점을 미리 등록해 둡니다. (v7에는 내 평점 목록 GET이 없어 등록 결과만 보관합니다)
/// 등록 기록(creates/log)은 비워 두어 테스트가 이후 요청만 확인하게 합니다.
Future<void> seedSessionRatings(
  WidgetTester tester,
  TestApp app,
  List<RatingDto> ratings,
) async {
  final store = Provider.of<SessionRatingsViewModel>(
    tester.element(find.byType(Navigator).first),
    listen: false,
  );
  for (final rating in ratings) {
    app.ratingApi.onCreate = (_) async =>
        app.ratingApi.server[rating.ratingId] = rating;
    await store.create(
      movieId: rating.movieId,
      score: rating.score,
      comment: rating.comment,
    );
  }
  app.ratingApi
    ..onCreate = null
    ..creates.clear()
    ..log.clear();
  await tester.pumpAndSettle();
}
