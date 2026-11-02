import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../data/services/member_check_service.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';

import '../screens/button_demo_screen.dart';
import '../screens/home_screen.dart';
import '../screens/movie_detail_screen.dart';
import '../screens/movies_screen.dart';
import '../screens/my_ratings_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/start_screen.dart';
import '../view_models/movie_home_view_model.dart';
import '../view_models/movie_list_view_model.dart';
import '../view_models/my_ratings_view_model.dart';
import '../view_models/signup_view_model.dart';
import '../widgets/main_navigation_shell.dart';

GoRouter createAppRouter({String initialLocation = '/'}) {
  // 앱 전체의 root Navigator입니다. 하단 NavigationBar를 가려야 하는 자식 화면은
  // parentNavigatorKey로 이 Navigator 위에 쌓습니다.
  // 테스트처럼 router를 여러 번 만들 때 키가 겹치지 않도록 router마다 새로 만듭니다.
  final rootNavigatorKey = GlobalKey<NavigatorState>();

  return GoRouter(
    initialLocation: initialLocation,
    navigatorKey: rootNavigatorKey,
    routes: [
      GoRoute(path: '/', builder: (context, state) => const StartScreen()),
      GoRoute(
        path: '/signup',
        builder: (context, state) => ChangeNotifierProvider<SignUpViewModel>(
          create: (context) =>
              SignUpViewModel(context.read<MemberCheckService>()),
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
                    builder: (context, state) =>
                        ChangeNotifierProvider<MyRatingsViewModel>(
                          create: (context) => MyRatingsViewModel(
                            context.read<RatingApiService>(),
                            context.read<TmdbMovieService>(),
                            sampleMemberId, // 6주차는 학습용 memberId 1입니다.
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
      // MovieLogButton 너비·상태 비교용 개발 화면입니다. Release 빌드에는 넣지 않습니다.
      if (kDebugMode)
        GoRoute(
          path: '/dev/buttons',
          builder: (context, state) => const ButtonDemoScreen(),
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
}
