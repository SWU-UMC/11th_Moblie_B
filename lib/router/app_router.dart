import '../data/services/sign_up_service.dart';
import '../data/services/rating_api_service.dart';
import '../view_models/sign_up_view_model.dart';
import '../view_models/my_ratings_view_model.dart';
import '../screens/my_ratings_screen.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../account_screens.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../screens/movie_detail_loader.dart';
import '../view_models/learning_member_session.dart';
import '../movie_screens.dart';

import 'package:provider/provider.dart';

import '../data/services/tmdb_movie_service.dart';
import '../view_models/movie_home_view_model.dart';
import '../view_models/movie_list_view_model.dart';

class AppRouter {
  AppRouter._();

  static final rootNavigatorKey = GlobalKey<NavigatorState>();
  static final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    // Guided Practice에서는 '/home', 전체 흐름 확인은 '/start'.
    initialLocation: '/start',
    routes: [
      GoRoute(path: '/start', builder: (context, state) => const StartScreen()),
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
                builder: (context, state) {
                  final id = context.read<LearningMemberSession>().memberId;
                  if (id == null) {
                    return Scaffold(
                      appBar: AppBar(
                        centerTitle: true,
                        title: const Text('내가 등록한 평점'),
                      ),
                      body: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('학습용 회원가입이 필요합니다.'),
                            TextButton(
                              onPressed: () => context.go('/register'),
                              child: const Text('회원가입'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return ChangeNotifierProvider(
                    create: (context) => MyRatingsViewModel(
                      context.read<RatingApiService>(),
                      context.read<TmdbMovieService>(),
                      id,
                    )..load(),
                    child: const MyRatingsScreen(),
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
