import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../data/movie_preferences.dart';
import '../data/services/member_check_service.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../screens/home_screen.dart';
import '../screens/main_screen.dart';
import '../screens/movie_detail_screen.dart';
import '../screens/movie_list_screen.dart';
import '../screens/my_ratings_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/sign_up_screen.dart';
import '../screens/start_screen.dart';
import '../view_models/movie_detail_view_model.dart';
import '../view_models/movie_home_view_model.dart';
import '../view_models/movie_list_view_model.dart';
import '../view_models/my_ratings_view_model.dart';
import '../view_models/sign_up_view_model.dart';
import 'app_routes.dart';

class AppRouter {
  AppRouter._();

  static final router = createRouter();

  /// 테스트에서는 preferences를 메모리 저장소로 넣음
  static GoRouter createRouter({
    String initialLocation = AppRoutes.start,
    MoviePreferences? preferences,
  }) {
    // NavigationBar 없이 띄울 화면들은 이 key 사용
    final rootNavigatorKey = GlobalKey<NavigatorState>();

    return GoRouter(
      initialLocation: initialLocation,
      navigatorKey: rootNavigatorKey,
      routes: [
        GoRoute(
          path: AppRoutes.start,
          builder: (context, state) => const StartScreen(),
        ),
        GoRoute(
          path: AppRoutes.register,
          builder: (context, state) => ChangeNotifierProvider(
            create: (context) =>
                SignUpViewModel(context.read<MemberCheckService>()),
            child: const SignUpScreen(),
          ),
        ),
        // 상세는 탭 밖에 둬서 NavigationBar 안 보이게 함
        GoRoute(
          path: AppRoutes.movieDetail,
          builder: (context, state) => ChangeNotifierProvider(
            create: (context) => MovieDetailViewModel(
              context.read<TmdbMovieService>(),
              movieId: int.tryParse(
                state.pathParameters[AppRoutes.movieIdParam] ?? '',
              ),
              // extra로 영화 받았으면 그대로 쓰고 없으면 id로 다시 불러옴
              movie: state.extra is TmdbMovieDto
                  ? state.extra! as TmdbMovieDto
                  : null,
            )..load(),
            child: const MovieDetailScreen(),
          ),
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
                  routes: [
                    GoRoute(
                      path: AppRoutes.myRatingsSegment, // /my/ratings
                      // root Navigator에 띄워서 하단 바 가림
                      parentNavigatorKey: rootNavigatorKey,
                      builder: (context, state) => ChangeNotifierProvider(
                        create: (context) => MyRatingsViewModel(
                          context.read<RatingApiService>(),
                          context.read<TmdbMovieService>(),
                          sampleMemberId, // 학습용 memberId 1
                        )..load(),
                        child: const MyRatingsScreen(),
                      ),
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
