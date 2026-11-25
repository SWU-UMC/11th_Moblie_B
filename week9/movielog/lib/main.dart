import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/network/movie_log_client.dart';
import 'core/network/tmdb_client.dart';
import 'core/session/auth_session_bridge.dart';
import 'core/session/session_guard.dart';
import 'core/storage/token_storage.dart';
import 'data/movie_preferences.dart';
import 'data/services/auth_api_service.dart';
import 'data/services/favorite_api_service.dart';
import 'data/services/member_api_service.dart';
import 'data/services/rating_api_service.dart';
import 'data/services/sign_up_service.dart';
import 'data/services/tmdb_movie_service.dart';
import 'router/app_router.dart';
import 'router/app_routes.dart';
import 'theme/app_theme.dart';
import 'view_models/auth_view_model.dart';
import 'view_models/session_ratings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // .env 먼저 읽고 runApp 해야 토큰이 안 비어있음
  await dotenv.load(fileName: '.env');
  runApp(const MovieLogApp());
}

/// Service·ViewModel 등록
/// 테스트에서 가짜 Service·저장소 넣으려고 전부 선택 인자로 받음
class MovieLogApp extends StatefulWidget {
  const MovieLogApp({
    super.key,
    this.movieService,
    this.signUpService,
    this.authApiService,
    this.memberApiService,
    this.ratingApiService,
    this.favoriteApiService,
    this.tokenStorage,
    this.preferences,
    this.initialLocation = AppRoutes.start,
  });

  final TmdbMovieService? movieService;
  final SignUpService? signUpService;
  final AuthApiService? authApiService;
  final MemberApiService? memberApiService;
  final RatingApiService? ratingApiService;
  final FavoriteApiService? favoriteApiService;
  final TokenStorage? tokenStorage;
  final MoviePreferences? preferences;
  final String initialLocation;

  @override
  State<MovieLogApp> createState() => _MovieLogAppState();
}

class _MovieLogAppState extends State<MovieLogApp> {
  // 앱 살아 있는 동안 한 번만 만듦 (build마다 만들면 세션·Router 위치 날아감)
  late final TokenStorage _tokenStorage;
  late final SessionRatings _sessionRatings;
  late final AuthViewModel _auth;
  late final MoviePreferences _preferences;
  late final TmdbMovieService _movieService;
  late final SignUpService _signUpService;
  late final MemberApiService _memberApi;
  late final RatingApiService _ratingApi;
  late final FavoriteApiService _favoriteApi;
  late final AuthSessionBridge _sessionBridge;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _tokenStorage =
        widget.tokenStorage ?? SecureTokenStorage(const FlutterSecureStorage());
    // 공개 Client: 로그인·회원가입·중복 확인·유저별 평점 조회 (토큰 없음)
    final publicClient = createMovieLogClient();
    // 보호 Client: 내 정보·평점 쓰기 (AuthInterceptor가 Bearer 붙임)
    final authClient = createAuthMovieLogClient(_tokenStorage);

    // TMDB Client는 따로 (MovieLog JWT 안 실림)
    _movieService = widget.movieService ?? TmdbMovieService(createTmdbClient());
    _signUpService = widget.signUpService ?? SignUpService(publicClient);
    _memberApi = widget.memberApiService ?? MemberApiService(authClient);
    _ratingApi =
        widget.ratingApiService ?? RatingApiService(publicClient, authClient);
    // 즐겨찾기는 전부 보호 요청 → 8주차 보호 Dio 그대로 (새로 안 만듦)
    _favoriteApi = widget.favoriteApiService ?? FavoriteApiService(authClient);
    _preferences = widget.preferences ?? MoviePreferences();
    _sessionRatings = SessionRatings();
    _auth = AuthViewModel(
      widget.authApiService ?? AuthApiService(publicClient),
      _memberApi,
      _tokenStorage,
      sessionRatings: _sessionRatings,
    );
    // AuthViewModel 세션 바뀔 때 SessionGuard 갱신 (Route보다 먼저 만들어 둠)
    _sessionBridge = AuthSessionBridge(
      authSignals: _auth,
      sessionVersion: () => _auth.sessionVersion,
      // signedIn + GET me 끝난 email만 현재 계정으로 씀
      verifiedEmail: () =>
          _auth.status == AuthStatus.signedIn ? _auth.member?.email : null,
    );
    _router = AppRouter.createRouter(
      _auth,
      initialLocation: widget.initialLocation,
      preferences: _preferences,
    );
    // 첫 build 끝나고 세션 복원 시작 (토큰 읽기 → GET me)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _auth.restoreSession();
    });
  }

  @override
  void dispose() {
    _router.dispose();
    _sessionBridge.dispose();
    _auth.dispose();
    _sessionRatings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<TokenStorage>.value(value: _tokenStorage),
        Provider<MoviePreferences>.value(value: _preferences),
        Provider<TmdbMovieService>.value(value: _movieService),
        Provider<SignUpService>.value(value: _signUpService),
        Provider<MemberApiService>.value(value: _memberApi),
        Provider<RatingApiService>.value(value: _ratingApi),
        Provider<FavoriteApiService>.value(value: _favoriteApi),
        Provider<AuthSessionBridge>.value(value: _sessionBridge),
        Provider<SessionGuard>.value(value: _sessionBridge.guard),
        ChangeNotifierProvider<SessionRatings>.value(value: _sessionRatings),
        ChangeNotifierProvider<AuthViewModel>.value(value: _auth),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'MovieLog',
        theme: AppTheme.light,
        routerConfig: _router,
      ),
    );
  }
}
