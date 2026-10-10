import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:movielog/data/movie_preferences.dart';
import 'package:movielog/main.dart';
import 'package:movielog/models/movie.dart';
import 'package:movielog/models/movie_sort.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/router/app_routes.dart';
import 'package:movielog/services/fake_movie_service.dart';
import 'package:movielog/widgets/movie/movie_poster_card.dart';
import 'package:movielog/widgets/movie_list/movie_grid.dart';
import 'package:movielog/widgets/movie_list/movie_list_empty.dart';
import 'package:movielog/widgets/movie_list/movie_list_error.dart';
import 'package:movielog/widgets/movie_list/movie_list_loading.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const _loadDelay = Duration(seconds: 1);

/// fetchMovies가 몇 번 호출됐는지 세는 Mock Service
class _CountingMovieService extends FakeMovieService {
  _CountingMovieService() : super(delay: _loadDelay);

  int calls = 0;

  @override
  Future<List<Movie>> fetchMovies({
    MovieLoadMode mode = MovieLoadMode.success,
  }) {
    calls++;
    return super.fetchMovies(mode: mode);
  }
}

/// 영화 목록 화면에서 시작합니다. 아직 Future가 끝나지 않은 Loading 상태로 돌려줍니다.
Future<GoRouter> _pumpMovieList(
  WidgetTester tester, {
  FakeMovieService service = const FakeMovieService(delay: _loadDelay),
  String location = AppRoutes.movies,
}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = AppRouter.createRouter(
    initialLocation: location,
    movieService: service,
  );
  await tester.pumpWidget(MovieLogApp(router: router));
  await tester.pump();
  return router;
}

Future<void> _selectMockMode(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('Mock 응답 선택'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

String _firstCardTitle(WidgetTester tester) => tester
    .widget<MoviePosterCard>(find.byType(MoviePosterCard).first)
    .movie
    .title;

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('Loading이 먼저 보이고 약 1초 뒤 영화 Grid가 표시된다', (tester) async {
    await _pumpMovieList(tester);
    expect(find.byType(MovieListLoading), findsOneWidget);
    expect(find.byType(MovieGrid), findsNothing);

    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byType(MovieListLoading), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(MovieListLoading), findsNothing);
    expect(find.byType(MovieGrid), findsOneWidget);
  });

  testWidgets('빈 목록이면 Empty 화면을 보여준다', (tester) async {
    await _pumpMovieList(tester);
    await tester.pump(_loadDelay);

    await _selectMockMode(tester, '빈 목록');
    expect(find.byType(MovieListLoading), findsOneWidget);
    await tester.pump(_loadDelay);

    expect(find.byType(MovieListEmpty), findsOneWidget);
    expect(find.text('아직 등록된 영화가 없어요.'), findsOneWidget);
  });

  testWidgets('실패하면 Error 화면이 보이고, 다시 시도하면 Loading 후 성공한다', (tester) async {
    final service = _CountingMovieService();
    await _pumpMovieList(tester, service: service);
    await tester.pump(_loadDelay);

    await _selectMockMode(tester, '실패');
    await tester.pump(_loadDelay);

    expect(find.byType(MovieListError), findsOneWidget);
    expect(find.text('영화를 불러오지 못했습니다.'), findsOneWidget);
    // 내부 Exception 이름은 화면에 보이지 않습니다.
    expect(find.textContaining('MovieLoadException'), findsNothing);

    final callsBeforeRetry = service.calls;
    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    expect(service.calls, callsBeforeRetry + 1);
    expect(find.byType(MovieListLoading), findsOneWidget);

    await tester.pump(_loadDelay);
    expect(find.byType(MovieGrid), findsOneWidget);
  });

  testWidgets('응답이 5초 안에 오지 않으면 Timeout 안내를 보여준다', (tester) async {
    await _pumpMovieList(tester);
    await tester.pump(_loadDelay);

    await _selectMockMode(tester, '응답 지연');
    await tester.pump(const Duration(seconds: 5));

    expect(find.byType(MovieListError), findsOneWidget);
    expect(find.textContaining('응답이 늦어지고 있어요.'), findsOneWidget);

    // 남아 있는 지연 Timer를 끝까지 흘려보냅니다.
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('장르 Chip으로 화면이 다시 그려져도 Future를 새로 만들지 않는다', (tester) async {
    final service = _CountingMovieService();
    await _pumpMovieList(tester, service: service);
    await tester.pump(_loadDelay);
    expect(service.calls, 1);

    await tester.tap(find.widgetWithText(ChoiceChip, 'SF'));
    await tester.pumpAndSettle();

    expect(service.calls, 1);
    expect(find.byType(MoviePosterCard), findsNWidgets(2));
  });

  testWidgets('당겨서 새로고침하면 기존 목록을 유지한 채 다시 불러온다', (tester) async {
    final service = _CountingMovieService();
    await _pumpMovieList(tester, service: service);
    await tester.pump(_loadDelay);

    await tester.fling(find.byType(MovieGrid), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(service.calls, 2);
    expect(find.byType(MovieListLoading), findsNothing);
    expect(find.byType(MovieGrid), findsOneWidget);

    await tester.pump(_loadDelay);
    await tester.pumpAndSettle();
  });

  testWidgets('선택한 장르와 정렬을 SharedPreferencesAsync에 저장한다', (tester) async {
    await _pumpMovieList(tester);
    await tester.pump(_loadDelay);

    await tester.tap(find.widgetWithText(ChoiceChip, 'SF'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('정렬'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('제목순'));
    await tester.pumpAndSettle();

    final preferences = MoviePreferences();
    expect(await preferences.readGenres(), {'SF'});
    expect(await preferences.readSort(), MovieSort.title);
  });

  testWidgets('앱을 다시 실행하면 저장된 장르와 정렬이 복원된다', (tester) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
          MoviePreferences.selectedGenresKey: ['로맨스'],
          MoviePreferences.sortKey: MovieSort.title.name,
        });

    final router = await _pumpMovieList(tester);
    await tester.pump(_loadDelay);
    await tester.pumpAndSettle();

    expect(_location(router), AppRoutes.moviesWithGenres({'로맨스'}));
    // 로맨스: 별빛 아래 우리, 봄날의 커피 → 제목순
    expect(find.byType(MoviePosterCard), findsNWidgets(2));
    expect(_firstCardTitle(tester), '별빛 아래 우리');
  });

  testWidgets('선택한 장르의 영화가 없으면 안내 후 전체 보기로 돌아간다', (tester) async {
    final router = await _pumpMovieList(
      tester,
      location: AppRoutes.moviesWithGenres({'없는장르'}),
    );
    await tester.pump(_loadDelay);

    expect(find.text('선택한 장르의 영화가 없어요.'), findsOneWidget);
    await tester.tap(find.text('전체 보기'));
    await tester.pumpAndSettle();

    expect(_location(router), AppRoutes.movies);
    expect(find.byType(MovieGrid), findsOneWidget);
  });
}
