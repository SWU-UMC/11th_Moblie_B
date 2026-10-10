import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/movie_preferences.dart';
import '../screens/home_screen.dart';
import '../services/fake_movie_service.dart';
import '../screens/main_screen.dart';
import '../screens/movie_detail_screen.dart';
import '../screens/movie_list_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/sign_up_screen.dart';
import '../screens/start_screen.dart';
import 'app_routes.dart';

class AppRouter {
  AppRouter._();

  /// 앱 전체에서 하나의 Router를 사용합니다.
  static final router = createRouter();

  /// 테스트에서는 [movieService]·[preferences]를 바꿔 끼워 빠르게 확인합니다.
  static GoRouter createRouter({
    String initialLocation = AppRoutes.start,
    FakeMovieService movieService = const FakeMovieService(),
    MoviePreferences? preferences,
  }) {
    return GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: AppRoutes.start,
          builder: (context, state) => const StartScreen(),
        ),
        GoRoute(
          path: AppRoutes.register,
          builder: (context, state) => const SignUpScreen(),
        ),
        // 상세는 NavigationBar 없이 전체 화면으로 쌓이도록 탭 바깥에 둡니다.
        // 탭 화면에서 push하면 뒤로 가기로 원래 탭에 돌아옵니다.
        GoRoute(
          path: AppRoutes.movieDetail,
          builder: (context, state) => MovieDetailScreen(
            movieId: int.tryParse(
              state.pathParameters[AppRoutes.movieIdParam] ?? '',
            ),
          ),
        ),
        // 탭마다 독립된 Navigator를 두어 탭을 바꿔도 각 탭의 상태가 유지됩니다.
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              MainScreen(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.home,
                  builder: (context, state) => const HomeScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.movies,
                  builder: (context, state) => MovieListScreen(
                    selectedGenres: AppRoutes.genresFromQuery(
                      state.uri.queryParameters,
                    ),
                    movieService: movieService,
                    preferences: preferences,
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.my,
                  builder: (context, state) => const ProfileScreen(),
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
