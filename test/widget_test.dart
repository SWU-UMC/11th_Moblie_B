import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:movielog/data/models/tmdb_genre_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/main.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/screens/home_screen.dart';
import 'package:movielog/screens/movies_screen.dart';
import 'package:movielog/screens/signup_screen.dart';
import 'package:movielog/screens/start_screen.dart';
import 'package:movielog/services/genre_preferences.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/view_models/movie_home_view_model.dart';
import 'package:movielog/view_models/movie_list_view_model.dart';
import 'package:movielog/widgets/genre_filter_chips.dart';
import 'package:movielog/widgets/movie_card.dart';
import 'package:movielog/widgets/popular_movie_card.dart';
import 'package:movielog/widgets/tmdb_poster_image.dart';

const _sf = TmdbGenreDto(id: 878, name: 'SF');
const _drama = TmdbGenreDto(id: 18, name: '드라마');

TmdbMovieDto _movie(
  int id,
  String title, {
  List<int> genreIds = const [],
  String overview = '줄거리',
}) => TmdbMovieDto(
  id: id,
  title: title,
  overview: overview,
  // 테스트에서 네트워크 이미지를 받지 않도록 포스터는 비워 둡니다.
  posterPath: null,
  backdropPath: null,
  releaseDate: '2024-05-01',
  genreIds: genreIds,
  voteAverage: 7.5,
  popularity: 100,
);

TmdbMoviePageDto _page(List<TmdbMovieDto> results, {int totalPages = 1}) =>
    TmdbMoviePageDto(
      page: 1,
      results: results,
      totalPages: totalPages,
      totalResults: results.length,
    );

DioException _networkError() => DioException(
  requestOptions: RequestOptions(path: '/discover/movie'),
  message: 'network error',
);

/// 실제 서버 대신 정해진 결과를 돌려주고, 어떤 요청이 왔는지 기록하는 Service입니다.
class _FakeTmdbMovieService extends TmdbMovieService {
  _FakeTmdbMovieService({
    List<TmdbMovieDto>? popular,
    TmdbMoviePageDto Function(int page, int? genreId)? discover,
    this.delay = Duration.zero,
    this.failDiscoverTimes = 0,
  }) : popular = popular ?? [_movie(100, '인기 영화')],
       discover = discover ?? _defaultDiscover,
       super(Dio());

  final List<TmdbMovieDto> popular;
  final TmdbMoviePageDto Function(int page, int? genreId) discover;
  final Duration delay;
  int failDiscoverTimes;

  final discoverCalls = <(int page, int? genreId)>[];
  int popularCalls = 0;

  static TmdbMoviePageDto _defaultDiscover(int page, int? genreId) {
    final movies = [
      _movie(1, '우주 영화', genreIds: [_sf.id]),
      _movie(2, '드라마 영화', genreIds: [_drama.id], overview: ''),
    ];
    return _page(
      genreId == null
          ? movies
          : movies.where((movie) => movie.genreIds.contains(genreId)).toList(),
    );
  }

  @override
  Future<TmdbMoviePageDto> fetchPopular({int page = 1}) async {
    popularCalls++;
    await Future<void>.delayed(delay);
    return _page(popular);
  }

  @override
  Future<TmdbMoviePageDto> discoverMovies({
    required int page,
    int? genreId,
  }) async {
    discoverCalls.add((page, genreId));
    await Future<void>.delayed(delay);
    if (failDiscoverTimes > 0) {
      failDiscoverTimes--;
      throw _networkError();
    }
    return discover(page, genreId);
  }

  @override
  Future<List<TmdbGenreDto>> fetchGenres() async => const [_sf, _drama];
}

/// 불러오기·저장 결과를 테스트에서 직접 정하는 GenrePreferences입니다.
class _FakeGenrePreferences extends GenrePreferences {
  _FakeGenrePreferences(this._load, {this.save});

  final Future<int?> Function() _load;
  final Future<void> Function()? save;

  @override
  Future<int?> loadLastGenreId() => _load();

  @override
  Future<void> saveLastGenreId(int? genreId) => save?.call() ?? Future.value();
}

void main() {
  // 실제 .env 대신 가짜 Token을 넣어 둡니다. (실제 요청은 보내지 않습니다.)
  setUpAll(() => dotenv.loadFromString(envString: 'TMDB_ACCESS_TOKEN=test'));

  // 테스트마다 비어 있는 메모리 저장소로 SharedPreferencesAsync를 대체합니다.
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  void useTallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpMovies(
    WidgetTester tester,
    TmdbMovieService service, {
    GenrePreferences? genrePreferences,
  }) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ChangeNotifierProvider(
          create: (_) =>
              MovieListViewModel(service, genrePreferences: genrePreferences)
                ..loadInitial(),
          child: const MoviesScreen(),
        ),
      ),
    );
  }

  Future<GoRouter> pumpApp(
    WidgetTester tester, {
    String initialLocation = '/',
    TmdbMovieService? service,
  }) async {
    useTallScreen(tester);
    final router = createAppRouter(initialLocation: initialLocation);
    await tester.pumpWidget(
      MovieLogApp(
        router: router,
        movieService: service ?? _FakeTmdbMovieService(),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  ChoiceChip chip(WidgetTester tester, String label) =>
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label));

  testWidgets('StartScreen shows title and CTA button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const StartScreen()),
    );

    expect(find.text('영화의 순간을\n기록하세요'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '시작하기'), findsOneWidget);
  });

  testWidgets('Start -> Signup -> Home, and back is blocked', (
    WidgetTester tester,
  ) async {
    final router = await pumpApp(tester);

    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();
    expect(find.text('회원가입'), findsOneWidget);
    expect(router.canPop(), isFalse);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '무비러버');
    await tester.enterText(fields.at(1), 'movie@example.com');
    await tester.enterText(fields.at(2), 'password123');
    await tester.tap(find.text('필수 약관에 동의합니다'));
    await tester.pump();
    await tester.tap(find.text('가입하기'));
    await tester.pumpAndSettle();

    expect(find.text('오늘은 어떤\n영화를 볼까요?'), findsOneWidget);
    expect(router.canPop(), isFalse);

    // 시스템 뒤로 가기를 눌러도 홈에 그대로 머뭅니다.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('오늘은 어떤\n영화를 볼까요?'), findsOneWidget);
  });

  testWidgets('Home featured card opens detail and returns back', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, initialLocation: '/home');

    await tester.tap(find.text('상세보기'));
    await tester.pumpAndSettle();

    expect(find.text('Cinema Archive'), findsOneWidget);
    expect(find.text('별빛 아래 우리'), findsOneWidget);
    expect(find.text('2024 • 로맨스/드라마 • 124분'), findsOneWidget);

    // AppBar의 첫 번째 IconButton이 뒤로가기 버튼입니다.
    await tester.tap(find.byType(IconButton).first);
    await tester.pumpAndSettle();

    expect(find.text('오늘은 어떤\n영화를 볼까요?'), findsOneWidget);
  });

  testWidgets('Home shows at most 5 popular movies and requests once', (
    WidgetTester tester,
  ) async {
    final service = _FakeTmdbMovieService(
      popular: [for (var i = 1; i <= 7; i++) _movie(i, '인기 $i')],
    );
    await pumpApp(tester, initialLocation: '/home', service: service);

    // 7개가 와도 ViewModel은 앞의 5개만 보관합니다.
    final viewModel = tester
        .element(find.byType(HomeScreen))
        .read<MovieHomeViewModel>();
    expect(viewModel.popularMovies.map((movie) => movie.title), [
      '인기 1',
      '인기 2',
      '인기 3',
      '인기 4',
      '인기 5',
    ]);
    expect(find.byType(PopularMovieCard), findsAtLeastNWidgets(1));

    // 탭을 오가도 Popular 요청은 다시 보내지 않습니다.
    await tester.tap(find.text('영화'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('홈'));
    await tester.pumpAndSettle();
    expect(service.popularCalls, 1);
  });

  testWidgets('Home shows fewer than 5 popular movies without error', (
    WidgetTester tester,
  ) async {
    final service = _FakeTmdbMovieService(
      popular: [_movie(1, '인기 1'), _movie(2, '인기 2')],
    );
    await pumpApp(tester, initialLocation: '/home', service: service);

    expect(tester.takeException(), isNull);
    expect(find.byType(PopularMovieCard), findsNWidgets(2));
  });

  testWidgets('NavigationBar switches tabs and genre chip refetches movies', (
    WidgetTester tester,
  ) async {
    final service = _FakeTmdbMovieService();
    await pumpApp(tester, initialLocation: '/home', service: service);

    await tester.tap(find.text('영화'));
    await tester.pumpAndSettle();
    expect(find.text('우주 영화'), findsOneWidget);
    expect(find.text('드라마 영화'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    // "전체"는 with_genres 없이(genreId null) page 1부터 요청합니다.
    expect(service.discoverCalls.last, (1, null));

    await tester.tap(find.widgetWithText(ChoiceChip, 'SF'));
    await tester.pumpAndSettle();
    expect(service.discoverCalls.last, (1, _sf.id));
    expect(find.text('우주 영화'), findsOneWidget);
    expect(find.text('드라마 영화'), findsNothing);

    await tester.tap(find.text('마이'));
    await tester.pumpAndSettle();
    expect(find.text('내 프로필'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
  });

  testWidgets('Detail rating dialog and favorite snackbar', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, initialLocation: '/movies/under-the-starlight');

    await tester.tap(find.text('평점 남기기'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    FilledButton saveButton() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, '저장'));
    expect(saveButton().onPressed, isNull);

    final stars = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byIcon(Icons.star_rounded),
    );
    await tester.tap(stars.last);
    await tester.pumpAndSettle();
    expect(saveButton().onPressed, isNotNull);

    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining('점을 남겼어요.'), findsOneWidget);

    await tester.tap(find.text('즐겨찾기'));
    await tester.pumpAndSettle();
    expect(find.text('즐겨찾기에 추가했어요.'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);

    await tester.tap(find.text('즐겨찾기 해제'));
    await tester.pumpAndSettle();
    expect(find.text('즐겨찾기에서 삭제했어요.'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
  });

  testWidgets('TMDB movie card passes its id to detail and rating dialog', (
    WidgetTester tester,
  ) async {
    final router = await pumpApp(tester, initialLocation: '/movies');

    await tester.tap(find.text('드라마 영화'));
    await tester.pumpAndSettle();

    // 경로에 TMDB id가 들어가고, 상세는 넘겨받은 DTO를 그립니다.
    expect(router.state.uri.path, '/movies/2');
    expect(find.text('드라마 영화'), findsOneWidget);
    // overview가 비어 있으면 안내 문구를 보여줍니다.
    expect(find.text('줄거리 정보가 없어요.'), findsOneWidget);

    final logs = <String>[];
    final originalDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
    try {
      await tester.tap(find.text('평점 남기기'));
      await tester.pumpAndSettle();
      final stars = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byIcon(Icons.star_rounded),
      );
      await tester.tap(stars.last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
    } finally {
      // Flutter 테스트는 본문이 끝날 때 debugPrint가 원래대로인지 확인합니다.
      debugPrint = originalDebugPrint;
    }

    expect(logs, contains(startsWith('[평점] movieId=2 ')));
  });

  testWidgets('Profile edit opens a bottom sheet', (WidgetTester tester) async {
    await pumpApp(tester, initialLocation: '/my');

    await tester.tap(find.text('프로필 수정'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '시네필');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('시네필'), findsOneWidget);
    expect(find.text('프로필을 수정했어요.'), findsOneWidget);
  });

  testWidgets('SignupScreen validates fields and toggles submit button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const SignupScreen()),
    );

    final submitButtonFinder = find.widgetWithText(ElevatedButton, '가입하기');
    ElevatedButton submitButton() =>
        tester.widget<ElevatedButton>(submitButtonFinder);

    expect(submitButton().onPressed, isNull);

    await tester.enterText(find.byType(TextFormField).at(0), 'a');
    await tester.pump();
    expect(find.text('닉네임은 2자 이상이어야 합니다.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), '무비러버');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'movie@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(2), 'password123');
    await tester.tap(find.text('필수 약관에 동의합니다'));
    await tester.pump();

    expect(submitButton().onPressed, isNotNull);
  });

  testWidgets('Genre chips are not clipped with large text scale', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: GenreFilterChips(
              genres: const [_drama],
              selectedGenreId: null,
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    final chipRect = tester.getRect(find.byType(ChoiceChip).first);
    final labelRect = tester.getRect(find.text('전체'));
    expect(labelRect.bottom, lessThanOrEqualTo(chipRect.bottom));
    expect(labelRect.top, greaterThanOrEqualTo(chipRect.top));
  });

  testWidgets('Movie card opens detail with keyboard', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, initialLocation: '/movies');

    // Tab으로 첫 번째 카드까지 포커스를 옮긴 뒤 Enter로 엽니다.
    for (var i = 0; i < 20; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focused = FocusManager.instance.primaryFocus?.context;
      if (focused != null &&
          focused.findAncestorWidgetOfExactType<MovieCard>() != null) {
        break;
      }
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.text('Cinema Archive'), findsOneWidget);
  });

  testWidgets('Profile edit sheet scrolls to save button on small screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = createAppRouter(initialLocation: '/my');
    await tester.pumpWidget(
      MovieLogApp(router: router, movieService: _FakeTmdbMovieService()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('프로필 수정'));
    await tester.pumpAndSettle();

    // 시트가 열린 상태에서 키보드가 올라온 상황을 흉내 냅니다.
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final saveButton = find.widgetWithText(FilledButton, '저장');
    await tester.scrollUntilVisible(
      saveButton,
      50,
      scrollable: find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(find.text('프로필을 수정했어요.'), findsOneWidget);
  });

  testWidgets('Movies shows loading then success', (tester) async {
    await pumpMovies(
      tester,
      _FakeTmdbMovieService(delay: const Duration(seconds: 1)),
    );
    await tester.pump();
    expect(find.text('영화 목록을 불러오고 있어요'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('우주 영화'), findsOneWidget);
  });

  testWidgets('Movies shows empty view for empty list', (tester) async {
    await pumpMovies(
      tester,
      _FakeTmdbMovieService(discover: (_, _) => _page(const [])),
    );
    await tester.pumpAndSettle();

    expect(find.text('아직 등록된 영화가 없어요.'), findsOneWidget);
    expect(find.byType(MovieCard), findsNothing);
  });

  testWidgets('Movies error hides exception and retries', (tester) async {
    final service = _FakeTmdbMovieService(failDiscoverTimes: 1);
    await pumpMovies(tester, service);
    await tester.pumpAndSettle();

    expect(find.text('영화를 불러오지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
    expect(find.textContaining('DioException'), findsNothing);

    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    expect(find.text('영화 목록을 불러오고 있어요'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('우주 영화'), findsOneWidget);
  });

  testWidgets('Genre chips are disabled while discover is loading', (
    tester,
  ) async {
    final service = _FakeTmdbMovieService(delay: const Duration(seconds: 1));
    await pumpMovies(tester, service);
    await tester.pump();
    expect(find.text('영화 목록을 불러오고 있어요'), findsOneWidget);

    expect(chip(tester, 'SF').onSelected, isNull);
    await tester.tap(find.widgetWithText(ChoiceChip, 'SF'));
    await tester.pumpAndSettle();

    // 로딩 중 누른 장르는 무시되고, "전체" 요청만 보냈습니다.
    expect(service.discoverCalls, [(1, null)]);
    expect(chip(tester, '전체').selected, isTrue);
    expect(chip(tester, 'SF').onSelected, isNotNull);
  });

  test('Discover collects at most 30 movies without duplicate ids', () async {
    // 페이지마다 20개씩 오고, 앞 페이지와 5개씩 겹칩니다.
    final service = _FakeTmdbMovieService(
      discover: (page, _) => _page([
        for (var i = 0; i < 20; i++)
          _movie((page - 1) * 15 + i, '영화 ${(page - 1) * 15 + i}'),
      ], totalPages: 10),
    );
    final viewModel = MovieListViewModel(service);
    addTearDown(viewModel.dispose);

    final movies = await viewModel.fetchUpToThirtyMovies();

    expect(movies, hasLength(30));
    expect(movies.map((movie) => movie.id).toSet(), hasLength(30));
    // 30개를 채운 뒤에는 다음 페이지를 요청하지 않습니다.
    expect(service.discoverCalls.map((call) => call.$1), [1, 2]);
  });

  test('Discover stops at the last page with fewer than 30', () async {
    final service = _FakeTmdbMovieService(
      discover: (page, _) => _page([
        for (var i = 0; i < 5; i++) _movie(page * 100 + i, '영화'),
      ], totalPages: 2),
    );
    final viewModel = MovieListViewModel(service);
    addTearDown(viewModel.dispose);

    final movies = await viewModel.fetchUpToThirtyMovies(genreId: _sf.id);

    expect(movies, hasLength(10));
    expect(service.discoverCalls, [(1, _sf.id), (2, _sf.id)]);
  });

  testWidgets('Selected genre is saved and restored', (tester) async {
    await pumpMovies(tester, _FakeTmdbMovieService());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'SF'));
    await tester.pumpAndSettle();
    expect(await GenrePreferences().loadLastGenreId(), _sf.id);

    // 앱 재실행처럼 화면을 완전히 새로 만듭니다.
    final service = _FakeTmdbMovieService();
    await tester.pumpWidget(const SizedBox());
    await pumpMovies(tester, service);
    await tester.pumpAndSettle();

    expect(chip(tester, 'SF').selected, isTrue);
    expect(service.discoverCalls.first, (1, _sf.id));
    expect(find.text('우주 영화'), findsOneWidget);
    expect(find.text('드라마 영화'), findsNothing);
  });

  testWidgets('Genre restore failure keeps default genre', (tester) async {
    await pumpMovies(
      tester,
      _FakeTmdbMovieService(),
      genrePreferences: _FakeGenrePreferences(
        () => Future.error(Exception('read failed')),
      ),
    );
    await tester.pumpAndSettle();

    expect(chip(tester, '전체').selected, isTrue);
    expect(find.text('드라마 영화'), findsOneWidget);
  });

  testWidgets('Start buttons are reachable on short screen', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const StartScreen()),
    );

    await tester.scrollUntilVisible(
      find.text('시작하기'),
      100,
      scrollable: find.byType(Scrollable),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('로그인'), findsOneWidget);
    expect(tester.getRect(find.text('시작하기')).bottom, lessThanOrEqualTo(480));
  });

  testWidgets('Genre save failure keeps selection', (tester) async {
    await pumpMovies(
      tester,
      _FakeTmdbMovieService(),
      genrePreferences: _FakeGenrePreferences(
        () async => null,
        save: () => Future.error(Exception('write failed')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'SF'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(chip(tester, 'SF').selected, isTrue);
  });

  testWidgets('Poster placeholder shows for null poster_path', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TmdbPosterImage(posterPath: null, width: 100, height: 150),
      ),
    );

    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  test('TmdbMovieDto converts snake_case, null and num values', () {
    final movie = TmdbMovieDto.fromJson({
      'id': 550,
      'title': null,
      'overview': null,
      'poster_path': null,
      'release_date': null,
      'genre_ids': [18, 53.0],
      'vote_average': 8,
      'popularity': 120.5,
    });

    expect(movie.id, 550);
    expect(movie.title, '제목 없음');
    expect(movie.overview, '');
    expect(movie.posterPath, isNull);
    expect(movie.releaseYear, isNull);
    expect(movie.genreIds, [18, 53]);
    expect(movie.voteAverage, 8.0);
    expect(movie.popularity, 120.5);
  });
}
