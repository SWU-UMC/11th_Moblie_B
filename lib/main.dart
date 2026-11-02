import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/network/tmdb_client.dart';
import 'data/services/debug_tmdb_movie_service.dart';
import 'data/services/tmdb_movie_service.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Token을 읽기 전에 .env 로드를 끝내야 빈 값이 들어가지 않습니다.
  await dotenv.load(fileName: '.env');
  runApp(MovieLogApp());
}

final _appRouter = createAppRouter();

class MovieLogApp extends StatelessWidget {
  MovieLogApp({super.key, GoRouter? router, this.movieService})
    : router = router ?? _appRouter;

  final GoRouter router;

  /// 테스트에서 TMDB Service를 바꿔 끼울 때 사용합니다.
  final TmdbMovieService? movieService;

  // 여러 화면이 함께 쓰는 Service는 MaterialApp.router 위에 등록합니다.
  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      Provider<TmdbMovieService>(
        create: (_) => movieService ?? _createMovieService(),
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

/// 기본은 실제 TMDB Service를 쓰고, MOVIE_LOAD_MODE를 주면 결과를 바꾼 Service를 씁니다.
TmdbMovieService _createMovieService() {
  final mode = MovieLoadMode.fromEnvironment();
  if (mode == MovieLoadMode.success) {
    return TmdbMovieService(createTmdbClient());
  }
  return DebugTmdbMovieService(createTmdbClient(), mode: mode);
}
