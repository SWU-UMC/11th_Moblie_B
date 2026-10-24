import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../data/movie_preferences.dart';
import '../data/services/tmdb_movie_service.dart';
import '../screens/home_screen.dart';
import '../screens/main_screen.dart';
import '../screens/movie_detail_screen.dart';
import '../screens/movie_list_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/sign_up_screen.dart';
import '../screens/start_screen.dart';
import '../view_models/movie_detail_view_model.dart';
import '../view_models/movie_home_view_model.dart';
import '../view_models/movie_list_view_model.dart';
import 'app_routes.dart';

class AppRouter {
  AppRouter._();

  /// 앱 전체에서 하나의 Router를 사용합니다.
  static final router = createRouter();

  /// 테스트에서는 [preferences]를 메모리 저장소로 바꿔 끼웁니다.
  static GoRouter createRouter({
    String initialLocation = AppRoutes.start,
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
        GoRoute(
          path: AppRoutes.movieDetail,
          builder: (context, state) => ChangeNotifierProvider(
            create: (context) => MovieDetailViewModel(
              context.read<TmdbMovieService>(),
              movieId: int.tryParse(
                state.pathParameters[AppRoutes.movieIdParam] ?? '',
              ),
              // 목록에서 넘겨받은 영화가 있으면 바로 보여주고, 없으면 id로 다시 불러옵니다.
              movie: state.extra is TmdbMovieDto
                  ? state.extra! as TmdbMovieDto
                  : null,
            )..load(),
            child: const MovieDetailScreen(),
          ),
        ),
        // 탭마다 독립된 Navigator를 두어 탭을 바꿔도 각 탭의 상태(ViewModel)가 유지됩니다.
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
                  builder: (context, state) => ChangeNotifierProvider(
                    create: (context) => MovieListViewModel(
                      context.read<TmdbMovieService>(),
                      preferences: preferences,
                    )..loadInitial(),
                    child: const MovieListScreen(),
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
