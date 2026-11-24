import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/session/session_guard.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/movie_preferences.dart';
import '../data/services/favorite_api_service.dart';
import '../data/services/member_api_service.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/sign_up_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/main_screen.dart';
import '../screens/movie_detail_screen.dart';
import '../screens/movie_list_screen.dart';
import '../screens/movie_search_screen.dart';
import '../screens/my_ratings_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/sign_up_screen.dart';
import '../screens/splash_screen.dart';
import '../view_models/auth_view_model.dart';
import '../view_models/edit_profile_view_model.dart';
import '../view_models/favorite_detail_view_model.dart';
import '../view_models/favorites_view_model.dart';
import '../view_models/movie_detail_view_model.dart';
import '../view_models/movie_home_view_model.dart';
import '../view_models/movie_list_view_model.dart';
import '../view_models/my_ratings_view_model.dart';
import '../view_models/paged_movies_view_model.dart';
import '../view_models/session_ratings.dart';
import '../view_models/sign_up_view_model.dart';
import '../widgets/movielog_button.dart';
import 'app_routes.dart';

/// 인증 상태별로 갈 곳 정함 (상태만 읽음, API 호출 안 함)
/// null이면 지금 위치 그대로
String? authRedirect(AuthStatus status, String location) {
  const publicPaths = {AppRoutes.login, AppRoutes.register};
  final atStart = location == AppRoutes.start;
  final atPublic = publicPaths.contains(location);

  return switch (status) {
    // 토큰 확인 중 / 확인 실패(재시도): Splash 유지
    // → 저장소 확인 전에 로그인·홈이 잠깐 보이는 것 막음
    AuthStatus.initializing ||
    AuthStatus.retryRequired => atStart ? null : AppRoutes.start,
    // 로그아웃 / 로그인 요청 중: 공개 화면만
    AuthStatus.signedOut ||
    AuthStatus.authenticating => atPublic ? null : AppRoutes.login,
    // 로그인됨: Splash·로그인·회원가입 → 홈
    AuthStatus.signedIn => (atStart || atPublic) ? AppRoutes.home : null,
  };
}

class AppRouter {
  AppRouter._();

  /// AuthViewModel 바뀌면 redirect 다시 돌도록 refreshListenable 연결
  /// build()마다 만들면 위치 초기화돼서 앱 쪽에서 한 번만 만듦
  /// 테스트에서는 preferences를 메모리 저장소로 넣음
  static GoRouter createRouter(
    AuthViewModel auth, {
    String initialLocation = AppRoutes.start,
    MoviePreferences? preferences,
  }) {
    // NavigationBar 없이 띄울 화면들은 이 key 사용
    final rootNavigatorKey = GlobalKey<NavigatorState>();

    return GoRouter(
      initialLocation: initialLocation,
      navigatorKey: rootNavigatorKey,
      // 닉네임 수정 같은 member 변경엔 안 돌고, 인증 상태 바뀔 때만 redirect
      refreshListenable: _AuthStatusListenable(auth),
      redirect: (context, state) => authRedirect(auth.status, state.uri.path),
      routes: [
        GoRoute(
          path: AppRoutes.start, // Splash: 확인 중 / 실패 시 재시도
          builder: (context, state) {
            final auth = context.watch<AuthViewModel>();
            return SplashScreen(
              message: auth.message,
              onRetry: auth.status == AuthStatus.retryRequired
                  ? auth.restoreSession
                  : null,
            );
          },
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: AppRoutes.register,
          builder: (context, state) => ChangeNotifierProvider(
            create: (context) => SignUpViewModel(context.read<SignUpService>()),
            child: const SignUpScreen(),
          ),
        ),
        // 검색: 정적인 search를 :movieId보다 먼저 등록 (순서 바뀌면 영화 id로 읽힘)
        // 영화 목록이랑 다른 PagedMoviesViewModel 인스턴스
        GoRoute(
          path: AppRoutes.movieSearch,
          builder: (context, state) => ChangeNotifierProvider(
            create: (context) =>
                PagedMoviesViewModel(tmdbApi: context.read<TmdbMovieService>()),
            child: MovieSearchScreen(
              onOpenMovie: (movie) =>
                  context.push(AppRoutes.movieDetailOf(movie.id), extra: movie),
            ),
          ),
        ),
        // 상세는 탭 밖에 둬서 NavigationBar 안 보이게 함
        GoRoute(
          path: AppRoutes.movieDetail,
          builder: (context, state) {
            final auth = context.watch<AuthViewModel>();
            final member = auth.member;
            final guard = context.read<SessionGuard>();
            // 내 정보 준비되고 현재 세션이랑 같을 때까지 로딩·재시도
            if (member == null || guard.accountId != member.email) {
              return _MemberPending(auth: auth, title: '영화 상세');
            }
            final movieId = int.tryParse(
              state.pathParameters[AppRoutes.movieIdParam] ?? '',
            );
            return MultiProvider(
              // 계정·세션 바뀌면 이전 사용자 ViewModel 버리고 새로 만듦
              // (닉네임 수정으론 안 바뀜)
              key: ValueKey('${member.email}:${guard.generation}'),
              providers: [
                ChangeNotifierProvider(
                  create: (context) => MovieDetailViewModel(
                    context.read<TmdbMovieService>(),
                    context.read<RatingApiService>(),
                    movieId: movieId,
                    // memberId 대신 토큰 세션
                    auth: auth,
                    sessionRatings: context.read<SessionRatings>(),
                    // extra로 영화 받았으면 그대로 쓰고 없으면 id로 다시 불러옴
                    movie: state.extra is TmdbMovieDto
                        ? state.extra! as TmdbMovieDto
                        : null,
                  )..load(),
                ),
                ChangeNotifierProvider(
                  create: (context) => FavoriteDetailViewModel(
                    // 즐겨찾기 path엔 TMDB movieId (favoriteId 아님)
                    movieId: movieId ?? 0,
                    favoriteApi: context.read<FavoriteApiService>(),
                    sessionGuard: guard,
                    accountId: member.email,
                    auth: auth,
                  ),
                ),
              ],
              child: const MovieDetailScreen(),
            );
          },
        ),
        // 탭마다 Navigator 따로 둬서 탭 바꿔도 상태 유지
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              MainScreen(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.home,
                  builder: (context, state) => ChangeNotifierProvider(
                    create: (context) =>
                        MovieHomeViewModel(context.read<TmdbMovieService>())
                          ..loadPopular(),
                    child: const HomeScreen(),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.movies,
                  // 목록 page 상태 + 장르·정렬 필터 (필터가 page 상태를 씀)
                  builder: (context, state) => ChangeNotifierProvider(
                    create: (context) => PagedMoviesViewModel(
                      tmdbApi: context.read<TmdbMovieService>(),
                    ),
                    child: ChangeNotifierProvider(
                      create: (context) => MovieListViewModel(
                        context.read<TmdbMovieService>(),
                        context.read<PagedMoviesViewModel>(),
                        preferences: preferences,
                      )..loadInitial(),
                      child: const MovieListScreen(),
                    ),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.my,
                  builder: (context, state) => const ProfileScreen(),
                  routes: [
                    GoRoute(
                      path: AppRoutes.myRatingsSegment, // /my/ratings
                      // root Navigator에 띄워서 하단 바 가림
                      parentNavigatorKey: rootNavigatorKey,
                      builder: (context, state) => ChangeNotifierProvider(
                        create: (context) => MyRatingsViewModel(
                          context.read<RatingApiService>(),
                          context.read<TmdbMovieService>(),
                          auth: context.read<AuthViewModel>(),
                          sessionRatings: context.read<SessionRatings>(),
                        )..load(),
                        child: const MyRatingsScreen(),
                      ),
                    ),
                    GoRoute(
                      path: AppRoutes.myFavoritesSegment, // /my/favorites
                      parentNavigatorKey: rootNavigatorKey,
                      builder: (context, state) {
                        final auth = context.watch<AuthViewModel>();
                        final member = auth.member;
                        final guard = context.read<SessionGuard>();
                        if (member == null || guard.accountId != member.email) {
                          return _MemberPending(auth: auth, title: '내 즐겨찾기');
                        }
                        return ChangeNotifierProvider(
                          // 계정 바뀌면 이전 계정 즐겨찾기 안 남게 새로 만듦
                          key: ValueKey('${member.email}:${guard.generation}'),
                          create: (context) => FavoritesViewModel(
                            favoriteApi: context.read<FavoriteApiService>(),
                            tmdbApi: context.read<TmdbMovieService>(),
                            sessionGuard: guard,
                            accountId: member.email,
                            auth: auth,
                          ),
                          child: FavoritesScreen(
                            // 상세 닫힐 때까지 기다림 → 돌아오면 목록 다시 조회
                            onOpenMovie: (movie) => context.push(
                              AppRoutes.movieDetailOf(movie.id),
                              extra: movie,
                            ),
                          ),
                        );
                      },
                    ),
                    GoRoute(
                      path: AppRoutes.profileEditSegment, // /my/profile/edit
                      parentNavigatorKey: rootNavigatorKey,
                      builder: (context, state) {
                        final auth = context.watch<AuthViewModel>();
                        // 내 정보 아직 없으면 수정 화면 대신 로딩·재시도
                        if (auth.member == null) {
                          return _MemberPending(auth: auth, title: '프로필 수정');
                        }
                        return ChangeNotifierProvider(
                          create: (context) => EditProfileViewModel(
                            context.read<MemberApiService>(),
                            auth,
                          ),
                          child: const EditProfileScreen(),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
      errorBuilder: (context, state) =>
          Scaffold(body: Center(child: Text('페이지를 찾을 수 없어요: ${state.uri}'))),
    );
  }
}

/// 내 정보(GET me)가 필요한 화면인데 아직 없을 때 (프로필 수정·즐겨찾기·상세)
/// 들어오자마자 한 번 불러보고, 실패하면 다시 시도
class _MemberPending extends StatefulWidget {
  const _MemberPending({required this.auth, required this.title});

  final AuthViewModel auth;
  final String title;

  @override
  State<_MemberPending> createState() => _MemberPendingState();
}

class _MemberPendingState extends State<_MemberPending> {
  @override
  void initState() {
    super.initState();
    // URL로 바로 들어와서 MainScreen을 안 거친 경우 대비 (이미 불러오는 중이면 무시)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.auth.memberStatus == MemberLoadStatus.idle) {
        widget.auth.loadMember();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.auth;
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text(widget.title)),
      body: Center(
        child: auth.memberStatus == MemberLoadStatus.error
            ? MovieLogButton(
                label: '내 정보 다시 조회',
                width: 160,
                onPressed: () => auth.loadMember(force: true),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}

/// AuthViewModel 알림 중 status가 바뀐 경우만 Router에 전달
/// member 교체(프로필 수정)까지 refresh하면 push한 화면 pop이랑 겹쳐서 화면이 되살아남
class _AuthStatusListenable extends ChangeNotifier {
  _AuthStatusListenable(this._auth) : _last = _auth.status {
    _auth.addListener(_onAuthChanged);
  }

  final AuthViewModel _auth;
  AuthStatus _last;

  void _onAuthChanged() {
    if (_auth.status == _last) return;
    _last = _auth.status;
    notifyListeners();
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}
