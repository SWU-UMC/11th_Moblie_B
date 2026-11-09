import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/network/movie_log_client.dart';
import 'core/network/tmdb_client.dart';
import 'data/services/debug_movie_log_services.dart';
import 'data/services/debug_tmdb_movie_service.dart';
import 'data/services/member_check_service.dart';
import 'data/services/rating_api_service.dart';
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
  MovieLogApp({
    super.key,
    GoRouter? router,
    this.movieService,
    this.memberCheckService,
    this.ratingApiService,
  }) : router = router ?? _appRouter;

  final GoRouter router;

  /// 테스트에서 TMDB Service를 바꿔 끼울 때 사용합니다.
  final TmdbMovieService? movieService;
  final MemberCheckService? memberCheckService;
  final RatingApiService? ratingApiService;

  // 여러 화면이 함께 쓰는 Service는 MaterialApp.router 위에 등록합니다.
  @override
  Widget build(BuildContext context) {
    // 워크북 백엔드를 부르는 두 Service는 Dio 하나를 함께 씁니다.
    // TMDB Client와는 baseUrl·헤더가 다르므로 절대 하나로 합치지 않습니다.
    final movieLogClient = createMovieLogClient();

    return MultiProvider(
      providers: [
        Provider<TmdbMovieService>(
          create: (_) => movieService ?? _createMovieService(),
        ),
        Provider<MemberCheckService>(
          create: (_) =>
              memberCheckService ?? _createMemberCheckService(movieLogClient),
        ),
        Provider<RatingApiService>(
          create: (_) =>
              ratingApiService ?? _createRatingApiService(movieLogClient),
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

/// 기본은 실제 TMDB Service를 쓰고, MOVIE_LOAD_MODE를 주면 결과를 바꾼 Service를 씁니다.
TmdbMovieService _createMovieService() {
  final mode = MovieLoadMode.fromEnvironment();
  if (mode == MovieLoadMode.success) {
    return TmdbMovieService(createTmdbClient());
  }
  return DebugTmdbMovieService(createTmdbClient(), mode: mode);
}

/// MEMBER_CHECK_MODE를 주면 중복 확인 결과를 바꾼 Service를 씁니다. (slow, error)
MemberCheckService _createMemberCheckService(Dio dio) {
  final mode = MemberCheckMode.fromEnvironment();
  if (mode == MemberCheckMode.success) return MemberCheckService(dio);
  return DebugMemberCheckService(dio, mode: mode);
}

/// RATING_LOAD_MODE를 주면 평점 조회 결과를 바꾼 Service를 씁니다.
/// (slow, empty, errorOnce)
RatingApiService _createRatingApiService(Dio dio) {
  final mode = RatingLoadMode.fromEnvironment();
  if (mode == RatingLoadMode.success) return RatingApiService(dio);
  return DebugRatingApiService(dio, mode: mode);
}
