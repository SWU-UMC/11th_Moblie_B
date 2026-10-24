import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/network/tmdb_client.dart';
import 'data/services/tmdb_movie_service.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // .env를 다 읽은 뒤에 앱을 시작해야 Token이 빈 값으로 읽히지 않습니다.
  await dotenv.load(fileName: '.env');
  runApp(MovieLogApp());
}

class MovieLogApp extends StatelessWidget {
  /// 테스트에서는 Router와 TMDB Service를 바꿔 끼웁니다.
  MovieLogApp({super.key, GoRouter? router, this.movieService})
    : router = router ?? AppRouter.router;

  final GoRouter router;
  final TmdbMovieService? movieService;

  @override
  Widget build(BuildContext context) {
    // 여러 화면이 함께 쓰는 Service는 앱 최상단에서 한 번만 만들어 공유합니다.
    return MultiProvider(
      providers: [
        Provider<TmdbMovieService>(
          create: (_) => movieService ?? TmdbMovieService(createTmdbClient()),
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
