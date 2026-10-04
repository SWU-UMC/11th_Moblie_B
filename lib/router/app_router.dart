import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../account_screens.dart';
import '../movie.dart';
import '../movie_screens.dart';

class AppRouter {
  AppRouter._();

  static final router = GoRouter(
    // Guided Practice에서는 '/home', 전체 흐름 확인은 '/start'.
    initialLocation: '/start',
    routes: [
      GoRoute(path: '/start', builder: (context, state) => const StartScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) =>
            const PopScope(canPop: false, child: SignUpScreen()),
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
                const PopScope(canPop: false, child: HomeScreen()),
          ),
          GoRoute(
            path: '/movies',
            builder: (context, state) => const MovieListScreen(),
          ),
          GoRoute(
            path: '/my',
            builder: (context, state) => const MyPageScreen(),
          ),
        ],
      ),
      // ShellRoute 바깥에 두어 상세에서는 하단 탭을 표시하지 않습니다.
      GoRoute(
        path: '/movies/:movieId',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['movieId'] ?? '');
          final movie = findMovieById(id);
          if (movie == null) return const MovieNotFoundScreen();
          return MovieDetailScreen(key: ValueKey(movie.id), movie: movie);
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
