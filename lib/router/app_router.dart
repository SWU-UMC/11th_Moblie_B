import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../data/services/tmdb_movie_service.dart';

import '../screens/home_screen.dart';
import '../screens/movie_detail_screen.dart';
import '../screens/movies_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/start_screen.dart';
import '../view_models/movie_home_view_model.dart';
import '../view_models/movie_list_view_model.dart';
import '../widgets/main_navigation_shell.dart';

GoRouter createAppRouter({String initialLocation = '/'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(path: '/', builder: (context, state) => const StartScreen()),
    GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
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
            ),
          ],
        ),
      ],
    ),
    // 상세 화면은 NavigationBar 없이 전체 화면으로 쌓이도록 Shell 밖에 둡니다.
    GoRoute(
      path: '/movies/:movieId',
      // 목록에서 넘긴 TMDB 영화는 extra로 받고, 없으면 mock 영화에서 찾습니다.
      builder: (context, state) => MovieDetailScreen(
        movieId: state.pathParameters['movieId']!,
        tmdbMovie: switch (state.extra) {
          final TmdbMovieDto movie => movie,
          _ => null,
        },
      ),
    ),
  ],
);
