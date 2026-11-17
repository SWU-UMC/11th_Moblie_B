import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../data/services/member_api_service.dart';
import '../data/services/sign_up_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../screens/button_demo_screen.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/movie_detail_loader.dart';
import '../screens/movies_screen.dart';
import '../screens/my_ratings_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/splash_screen.dart';
import '../view_models/auth_view_model.dart';
import '../view_models/edit_profile_view_model.dart';
import '../view_models/movie_home_view_model.dart';
import '../view_models/movie_list_view_model.dart';
import '../view_models/my_ratings_view_model.dart';
import '../view_models/session_ratings_view_model.dart';
import '../view_models/signup_view_model.dart';
import '../widgets/main_navigation_shell.dart';
import '../widgets/movielog_button.dart';

/// 로그인하지 않아도 볼 수 있는 화면입니다. 로그인 상태에서 열면 홈으로 보냅니다.
const _publicPaths = {'/login', '/signup'};

/// 인증 상태와 관계없이 열리는 개발용 화면입니다.
const _openPaths = {'/dev/buttons'};

/// 인증 상태만 보고 이동할 위치를 정합니다. 비동기 작업(API 호출)은 하지 않습니다.
///
/// - initializing·retryRequired: Splash(/start)에 머뭅니다. 원래 가려던 경로는
///   `from`에 담아 두었다가 세션 확인이 끝나면 상태에 맞게 이어서 보냅니다.
/// - signedOut·authenticating: 공개 화면(/login, /signup)만 허용합니다.
///   (from이 /signup이었다면 회원가입으로, 그 밖에는 로그인으로)
/// - signedIn: Splash·로그인·회원가입은 홈(또는 from의 보호 경로)으로 보냅니다.
String? authRedirect(AuthStatus status, Uri uri) {
  final path = uri.path;
  if (_openPaths.contains(path)) return null;
  final atStart = path == '/start';
  final atPublic = _publicPaths.contains(path);

  return switch (status) {
    AuthStatus.initializing ||
    AuthStatus.retryRequired => atStart ? null : _startRemembering(uri),
    AuthStatus.signedOut || AuthStatus.authenticating =>
      atPublic
          ? null
          : atStart
          ? _publicFrom(uri.queryParameters['from'])
          : '/login',
    AuthStatus.signedIn =>
      atStart
          ? _safeFrom(uri.queryParameters['from'])
          : atPublic
          ? '/home'
          : null,
  };
}

String _startRemembering(Uri uri) {
  final path = uri.path;
  if (path == '/') return '/start';
  return Uri(
    path: '/start',
    queryParameters: {'from': uri.toString()},
  ).toString();
}

/// 로그아웃 상태로 확인됐을 때, 원래 공개 화면을 열려던 경우만 그 화면으로 보냅니다.
String _publicFrom(String? from) {
  final path = from == null ? null : Uri.tryParse(from)?.path;
  return _publicPaths.contains(path) ? path! : '/login';
}

/// 앱 안의 보호 경로만 돌려보냅니다. 외부 주소·Splash·공개 화면은 홈으로 대신합니다.
String _safeFrom(String? from) {
  if (from == null || !from.startsWith('/') || from.startsWith('//')) {
    return '/home';
  }
  final path = Uri.tryParse(from)?.path ?? '';
  if (path == '/' || path == '/start' || _publicPaths.contains(path)) {
    return '/home';
  }
  return from;
}

/// [auth]의 상태가 바뀔 때마다 redirect를 다시 실행하는 Router를 만듭니다.
/// 앱이 살아 있는 동안 한 번만 만듭니다. (build마다 만들면 현재 위치가 초기화됩니다)
GoRouter createAppRouter(
  AuthViewModel auth, {
  String initialLocation = '/start',
}) {
  // 앱 전체의 root Navigator입니다. 하단 NavigationBar를 가려야 하는 자식 화면은
  // parentNavigatorKey로 이 Navigator 위에 쌓습니다.
  // 테스트처럼 router를 여러 번 만들 때 키가 겹치지 않도록 router마다 새로 만듭니다.
  final rootNavigatorKey = GlobalKey<NavigatorState>();

  return GoRouter(
    initialLocation: initialLocation,
    navigatorKey: rootNavigatorKey,
    // 로그인 상태(status)가 바뀔 때만 redirect를 다시 실행합니다.
    refreshListenable: auth.statusListenable,
    redirect: (context, state) => authRedirect(auth.status, state.uri),
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/home'),
      GoRoute(
        path: '/start', // Splash: 토큰 확인 중 / 확인 실패 시 재시도
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
        path: '/login',
        builder: (context, state) {
          final extra = state.extra;
          return LoginScreen(initialEmail: extra is String ? extra : null);
        },
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => ChangeNotifierProvider<SignUpViewModel>(
          create: (context) => SignUpViewModel(context.read<SignUpService>()),
          child: const SignupScreen(),
        ),
      ),
      // 홈, 영화, 마이 탭은 NavigationBar를 공유하고, 탭마다 화면 상태를 유지합니다.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainNavigationShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                // 탭 상태가 유지되므로 ViewModel 생성과 Popular 요청은 한 번만 일어납니다.
                builder: (context, state) =>
                    ChangeNotifierProvider<MovieHomeViewModel>(
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
                path: '/movies',
                builder: (context, state) =>
                    ChangeNotifierProvider<MovieListViewModel>(
                      create: (context) =>
                          MovieListViewModel(context.read<TmdbMovieService>())
                            ..loadInitial(),
                      child: const MoviesScreen(),
                    ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/my',
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'ratings', // 최종 경로: /my/ratings
                    // root Navigator 위에 표시해 하단 NavigationBar를 가립니다.
                    parentNavigatorKey: rootNavigatorKey,
                    // memberId 대신 이번 로그인 세션의 평점(토큰 기반 쓰기 결과)을 씁니다.
                    builder: (context, state) =>
                        ChangeNotifierProvider<MyRatingsViewModel>(
                          create: (context) => MyRatingsViewModel(
                            context.read<SessionRatingsViewModel>(),
                            context.read<TmdbMovieService>(),
                          )..load(),
                          child: const MyRatingsScreen(),
                        ),
                  ),
                  GoRoute(
                    path: 'profile/edit', // 최종 경로: /my/profile/edit
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final auth = context.watch<AuthViewModel>();
                      if (auth.member == null) {
                        return _MemberLoadingScreen(auth);
                      }
                      return ChangeNotifierProvider<EditProfileViewModel>(
                        create: (context) => EditProfileViewModel(
                          context.read<MemberApiService>(),
                          context.read<AuthViewModel>(),
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
      // MovieLogButton 너비·상태 비교용 개발 화면입니다. Release 빌드에는 넣지 않습니다.
      if (kDebugMode)
        GoRoute(
          path: '/dev/buttons',
          builder: (context, state) => const ButtonDemoScreen(),
        ),
      // 상세 화면은 NavigationBar 없이 전체 화면으로 쌓이도록 Shell 밖에 둡니다.
      GoRoute(
        path: '/movies/:movieId',
        // movieId는 URL 식별자로만 쓰고, 화면에 넘길 TMDB 영화는 extra에서 꺼냅니다.
        // extra가 없거나(직접 접근·Deep Link) id가 다르면 Loader가 TMDB에서 다시 조회합니다.
        builder: (context, state) {
          final movieId = state.pathParameters['movieId']!;
          final extra = state.extra;
          return MovieDetailLoader(
            // 다른 영화로 바뀌면 이전 영화의 상태·ViewModel을 재사용하지 않도록 새로 만듭니다.
            key: ValueKey(movieId),
            movieId: movieId,
            initialMovie: extra is TmdbMovieDto && '${extra.id}' == movieId
                ? extra
                : null,
          );
        },
      ),
    ],
  );
}

/// 프로필 수정 화면을 바로 열었는데 내 정보가 아직 없을 때의 화면입니다.
class _MemberLoadingScreen extends StatelessWidget {
  const _MemberLoadingScreen(this.auth);

  final AuthViewModel auth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('프로필 수정')),
      body: Center(
        child: auth.memberStatus == MemberLoadStatus.error
            ? MovieLogButton(
                label: '다시 시도',
                onPressed: () => auth.loadMember(force: true),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
