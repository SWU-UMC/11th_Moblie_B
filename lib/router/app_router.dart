import '../data/services/sign_up_service.dart';
import '../view_models/sign_up_view_model.dart';
import '../screens/my_ratings_screen.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../account_screens.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../screens/movie_detail_loader.dart';
import '../view_models/auth_view_model.dart';
import '../view_models/edit_profile_view_model.dart';
import '../data/services/member_api_service.dart';
import '../screens/login_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/edit_profile_screen.dart';
import '../movie_screens.dart';

import 'package:provider/provider.dart';

import '../data/services/tmdb_movie_service.dart';
import '../view_models/movie_home_view_model.dart';
import '../view_models/movie_list_view_model.dart';

class AppRouter {
  AppRouter._();

  static final rootNavigatorKey = GlobalKey<NavigatorState>();
  static GoRouter createRouter(AuthViewModel authViewModel) => GoRouter(
    refreshListenable: authViewModel,
    redirect: (context, state) =>
        authRedirect(authViewModel.status, state.uri.path),
    navigatorKey: rootNavigatorKey,
    // Guided Practice에서는 '/home', 전체 흐름 확인은 '/start'.
    initialLocation: '/start',
    routes: [
      GoRoute(
        path: '/start',
        builder: (context, state) {
          final auth = context.read<AuthViewModel>();
          return SplashScreen(
            message: auth.message,
            onRetry: auth.status == AuthStatus.retryRequired
                ? auth.restoreSession
                : null,
          );
        },
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => ChangeNotifierProvider(
          create: (context) => SignUpViewModel(context.read<SignUpService>()),
          child: const SignUpScreen(),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => MainScreen(
          currentIndex: indexFromLocation(state.uri.path),
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) =>
                ChangeNotifierProvider<MovieHomeViewModel>(
                  create: (context) =>
                      MovieHomeViewModel(context.read<TmdbMovieService>())
                        ..loadPopular(),
                  child: const PopScope(canPop: false, child: HomeScreen()),
                ),
          ),
          GoRoute(
            path: '/movies',
            builder: (context, state) =>
                ChangeNotifierProvider<MovieListViewModel>(
                  create: (context) =>
                      MovieListViewModel(context.read<TmdbMovieService>())
                        ..loadInitial(),
                  child: const MovieListScreen(),
                ),
          ),
          GoRoute(
            path: '/my',
            builder: (context, state) => const MyPageScreen(),
            routes: [
              GoRoute(
                path: 'ratings',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => const MyRatingsScreen(),
              ),
              GoRoute(
                path: 'profile/edit',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) {
                  final auth = context.read<AuthViewModel>();
                  if (auth.member == null) {
                    return Scaffold(
                      appBar: AppBar(title: const Text('프로필 수정')),
                      body: Center(
                        child: TextButton(
                          onPressed: () => auth.loadMember(force: true),
                          child: const Text('내 정보 불러오기'),
                        ),
                      ),
                    );
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
      // ShellRoute 바깥에 두어 상세에서는 하단 탭을 표시하지 않습니다.
      GoRoute(
        path: '/movies/:movieId',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['movieId'] ?? '');
          final extra = state.extra;
          if (id == null || id < 1) return const MovieNotFoundScreen();
          return MovieDetailLoader(
            key: ValueKey(id),
            movieId: id,
            initialMovie: extra is TmdbMovieDto && extra.id == id
                ? extra
                : null,
          );
        },
      ),
    ],
    errorBuilder: (context, state) => const MovieNotFoundScreen(),
  );

  static int indexFromLocation(String path) {
    if (path.startsWith('/movies')) return 1;
    if (path.startsWith('/my')) return 2;
    return 0;
  }
}

String? authRedirect(AuthStatus status, String location) {
  const publicPaths = {'/login', '/register'};
  final atStart = location == '/start';
  final atPublic = publicPaths.contains(location);
  return switch (status) {
    AuthStatus.initializing ||
    AuthStatus.retryRequired => atStart ? null : '/start',
    AuthStatus.signedOut ||
    AuthStatus.authenticating => atPublic ? null : '/login',
    AuthStatus.signedIn => (atStart || atPublic) ? '/home' : null,
  };
}
