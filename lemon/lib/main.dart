import 'package:dio/dio.dart';
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
import 'data/services/auth_api_service.dart';
import 'data/services/debug_movie_log_services.dart';
import 'data/services/debug_tmdb_movie_service.dart';
import 'data/services/favorite_api_service.dart';
import 'data/services/member_api_service.dart';
import 'data/services/rating_api_service.dart';
import 'data/services/sign_up_service.dart';
import 'data/services/tmdb_movie_service.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'view_models/auth_view_model.dart';
import 'view_models/session_ratings_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Token을 읽기 전에 .env 로드를 끝내야 빈 값이 들어가지 않습니다.
  await dotenv.load(fileName: '.env');
  runApp(const MovieLogApp());
}

class MovieLogApp extends StatelessWidget {
  const MovieLogApp({
    super.key,
    this.initialLocation = '/start',
    this.tokenStorage,
    this.movieService,
    this.signUpService,
    this.authApiService,
    this.memberApiService,
    this.ratingApiService,
    this.favoriteApiService,
    this.onRouterCreated,
  });

  /// 테스트에서 특정 화면부터 열 때 씁니다. 세션이 확인되면 이 경로로 돌아옵니다.
  final String initialLocation;

  /// 아래 값들은 테스트에서 실제 저장소·Service를 바꿔 끼울 때 사용합니다.
  final TokenStorage? tokenStorage;
  final TmdbMovieService? movieService;
  final SignUpService? signUpService;
  final AuthApiService? authApiService;
  final MemberApiService? memberApiService;
  final RatingApiService? ratingApiService;
  final FavoriteApiService? favoriteApiService;

  /// 테스트에서 현재 위치(router.state)를 확인할 때 씁니다.
  final ValueChanged<GoRouter>? onRouterCreated;

  // 여러 화면이 함께 쓰는 Service·ViewModel은 MaterialApp.router 위에 등록합니다.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<TokenStorage>(
          create: (_) =>
              tokenStorage ?? SecureTokenStorage(const FlutterSecureStorage()),
        ),
        // 공개용: 로그인·회원가입·중복 확인·유저별 평점 조회 (Interceptor 없음)
        Provider<Dio>(create: (_) => createMovieLogClient()),
        // 보호용: 내 정보·평점 쓰기 (AuthInterceptor 등록)
        // TMDB Client와는 끝까지 따로 둡니다. TMDB 요청에 MovieLog JWT가 실리면 안 됩니다.
        Provider<_AuthClient>(
          create: (context) => _AuthClient(
            createAuthMovieLogClient(context.read<TokenStorage>()),
          ),
        ),
        Provider<TmdbMovieService>(
          create: (_) => movieService ?? _createMovieService(),
        ),
        Provider<AuthApiService>(
          create: (context) =>
              authApiService ?? AuthApiService(context.read<Dio>()),
        ),
        Provider<SignUpService>(
          create: (context) =>
              signUpService ?? _createSignUpService(context.read<Dio>()),
        ),
        Provider<MemberApiService>(
          create: (context) =>
              memberApiService ??
              _createMemberApiService(context.read<_AuthClient>().dio),
        ),
        // 공개 조회는 publicClient, 등록·수정·삭제는 authClient로 보냅니다.
        Provider<RatingApiService>(
          create: (context) =>
              ratingApiService ??
              _createRatingApiService(
                context.read<Dio>(),
                context.read<_AuthClient>().dio,
              ),
        ),
        // 즐겨찾기는 JWT로 사용자를 구분하므로 보호용 Client로만 보냅니다.
        Provider<FavoriteApiService>(
          create: (context) =>
              favoriteApiService ??
              FavoriteApiService(context.read<_AuthClient>().dio),
        ),
        // Service를 주입받는 ViewModel입니다.
        ChangeNotifierProvider<AuthViewModel>(
          create: (context) => AuthViewModel(
            context.read<AuthApiService>(),
            context.read<MemberApiService>(),
            context.read<TokenStorage>(),
          ),
        ),
        // AuthViewModel의 세션 버전·검증된 email을 SessionGuard에 전달합니다.
        Provider<AuthSessionBridge>(
          create: (context) {
            final auth = context.read<AuthViewModel>();
            return AuthSessionBridge(
              authSignals: auth,
              sessionVersion: () => auth.sessionVersion,
              verifiedEmail: () => auth.status == AuthStatus.signedIn
                  ? auth.member?.email
                  : null,
            );
          },
          dispose: (_, bridge) => bridge.dispose(),
          // 화면이 읽기 전에 AuthViewModel의 변화를 놓치지 않도록 바로 만듭니다.
          lazy: false,
        ),
        Provider<SessionGuard>(
          create: (context) => context.read<AuthSessionBridge>().guard,
        ),
        // 이번 로그인 세션에서 등록한 평점입니다. 세션이 바뀌면 스스로 비웁니다.
        ChangeNotifierProvider<SessionRatingsViewModel>(
          create: (context) => SessionRatingsViewModel(
            context.read<RatingApiService>(),
            context.read<AuthViewModel>(),
          ),
        ),
      ],
      child: _MovieLogRouterApp(
        initialLocation: initialLocation,
        onRouterCreated: onRouterCreated,
      ),
    );
  }
}

/// 보호용 Dio를 공개용 Dio와 다른 타입으로 Provider에 등록하기 위한 포장입니다.
class _AuthClient {
  const _AuthClient(this.dio);
  final Dio dio;
}

/// GoRouter를 앱이 살아 있는 동안 한 번만 만들고, 첫 프레임 뒤 세션 복원을 시작합니다.
class _MovieLogRouterApp extends StatefulWidget {
  const _MovieLogRouterApp({
    required this.initialLocation,
    this.onRouterCreated,
  });

  final String initialLocation;
  final ValueChanged<GoRouter>? onRouterCreated;

  @override
  State<_MovieLogRouterApp> createState() => _MovieLogRouterAppState();
}

class _MovieLogRouterAppState extends State<_MovieLogRouterApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthViewModel>();
    _router = createAppRouter(auth, initialLocation: widget.initialLocation);
    widget.onRouterCreated?.call(_router);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) auth.restoreSession();
    });
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'MovieLog',
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}

/// 기본은 실제 TMDB Service를 쓰고, MOVIE_LOAD_MODE를 주면 결과를 바꾼 Service를 씁니다.
TmdbMovieService _createMovieService() {
  final mode = MovieLoadMode.fromEnvironment();
  if (mode == MovieLoadMode.success) {
    return TmdbMovieService(createTmdbClient());
  }
  return DebugTmdbMovieService(createTmdbClient(), mode: mode);
}

/// MEMBER_CHECK_MODE를 주면 회원가입 화면 요청 결과를 바꾼 Service를 씁니다.
/// (slow, error, staleAvailable)
SignUpService _createSignUpService(Dio dio) {
  final mode = MemberCheckMode.fromEnvironment();
  if (mode == MemberCheckMode.success) return SignUpService(dio);
  return DebugSignUpService(dio, mode: mode);
}

/// AUTH_RESTORE_MODE(slow, errorOnce)를 주면 앱 시작 시 GET me 결과를 바꾼 Service를 씁니다.
MemberApiService _createMemberApiService(Dio authDio) {
  final mode = AuthRestoreMode.fromEnvironment();
  if (mode == AuthRestoreMode.success) return MemberApiService(authDio);
  return DebugMemberApiService(authDio, restoreMode: mode);
}

/// RATING_WRITE_MODE(slow, error)를 주면 평점 쓰기 결과를 바꾼 Service를 씁니다.
RatingApiService _createRatingApiService(Dio publicDio, Dio authDio) {
  final mode = RatingWriteMode.fromEnvironment();
  if (mode == RatingWriteMode.success) {
    return RatingApiService(publicDio, authDio);
  }
  return DebugRatingApiService(publicDio, authDio, writeMode: mode);
}
