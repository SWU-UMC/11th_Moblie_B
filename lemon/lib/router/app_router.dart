import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/sign_up_service.dart';
import '../data/services/tmdb_movie_service.dart';

import '../screens/button_demo_screen.dart';
import '../screens/home_screen.dart';
import '../screens/movie_detail_loader.dart';
import '../screens/movies_screen.dart';
import '../screens/my_ratings_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/start_screen.dart';
import '../view_models/learning_member_session.dart';
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
                    builder: (context, state) {
                      // 6주차 고정 memberId 1 대신 회원가입으로 받은 학습용 회원을 씁니다.
                      final id = context.read<LearningMemberSession>().memberId;
                      if (id == null) return const _SignUpRequiredScreen();
                      return ChangeNotifierProvider<MyRatingsViewModel>(
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

/// 학습용 회원가입 전에 "내가 등록한 평점"을 열었을 때의 안내 화면입니다.
class _SignUpRequiredScreen extends StatelessWidget {
  const _SignUpRequiredScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('내가 등록한 평점'),
        leading: IconButton(
          tooltip: '뒤로 가기',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('학습용 회원가입이 필요합니다.'),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/signup'),
              child: const Text('회원가입하러 가기'),
            ),
          ],
        ),
      ),
    );
  }
}
