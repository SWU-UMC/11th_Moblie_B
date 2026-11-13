import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/network/movie_log_client.dart';
import 'core/network/tmdb_client.dart';
import 'data/services/rating_api_service.dart';
import 'data/services/sign_up_service.dart';
import 'data/services/tmdb_movie_service.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'view_models/learning_member_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // .env 먼저 읽고 runApp 해야 토큰이 안 비어있음
  await dotenv.load(fileName: '.env');
  runApp(MovieLogApp());
}

class MovieLogApp extends StatelessWidget {
  /// 테스트에서 Router, Service 갈아끼우려고 받음
  MovieLogApp({
    super.key,
    GoRouter? router,
    this.movieService,
    this.signUpService,
    this.ratingApiService,
    this.memberSession,
  }) : router = router ?? AppRouter.router;

  final GoRouter router;
  final TmdbMovieService? movieService;
  final SignUpService? signUpService;
  final RatingApiService? ratingApiService;

  /// 테스트에서 이미 가입한 상태로 시작할 때 넣음
  final LearningMemberSession? memberSession;

  @override
  Widget build(BuildContext context) {
    // 둘 다 워크북 서버라 Dio 하나 같이 씀
    // TMDB Dio랑은 따로 씀
    final movieLogClient = createMovieLogClient();

    // 여러 화면에서 쓰는 Service라 최상단에 등록
    return MultiProvider(
      providers: [
        Provider<TmdbMovieService>(
          create: (_) => movieService ?? TmdbMovieService(createTmdbClient()),
        ),
        // 가입 결과 memberId 보관 (영화 상세·마이페이지가 같이 읽음)
        ChangeNotifierProvider<LearningMemberSession>(
          create: (_) => memberSession ?? LearningMemberSession(),
        ),
        Provider<SignUpService>(
          create: (_) => signUpService ?? SignUpService(movieLogClient),
        ),
        Provider<RatingApiService>(
          create: (_) => ratingApiService ?? RatingApiService(movieLogClient),
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'MovieLog',
        theme: AppTheme.light,
        routerConfig: router,
      ),
    );
  }
}
