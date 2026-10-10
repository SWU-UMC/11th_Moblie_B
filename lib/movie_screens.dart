import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'movie.dart';
import 'fake_movie_service.dart';
import 'genre_preference.dart';

void showNotice(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
    ));
}

class MainScreen extends StatelessWidget {
  const MainScreen({super.key, required this.currentIndex, required this.child});
  final int currentIndex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          const paths = ['/home', '/movies', '/my'];
          context.go(paths[index]);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home), label: '홈'),
          NavigationDestination(icon: Icon(Icons.movie_outlined),
            selectedIcon: Icon(Icons.movie), label: '영화'),
          NavigationDestination(icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person), label: '마이'),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final movie = movies.first;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('MovieLog'),
        actions: [IconButton(
          tooltip: '영화 목록 보기',
          onPressed: () => context.go('/movies'),
          icon: const Icon(Icons.search),
        )],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('오늘은 어떤\n영화를 볼까요?', style: theme.textTheme.headlineLarge),
          const SizedBox(height: 24),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push('/movies/${movie.id}'),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 2 / 3,
                    child: Image.asset(movie.posterAsset, fit: BoxFit.cover),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [theme.colorScheme.scrim.withValues(alpha: 0),
                            theme.colorScheme.scrim],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 24, right: 24, bottom: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Chip(label: const Text('추천 신작'),
                          backgroundColor: theme.colorScheme.primaryContainer),
                        const SizedBox(height: 8),
                        Text(movie.title, style: theme.textTheme.headlineLarge
                          ?.copyWith(color: theme.colorScheme.onPrimary)),
                        Text('${movie.genre} · ${movie.minutes}분',
                          style: theme.textTheme.bodyLarge
                            ?.copyWith(color: theme.colorScheme.onPrimary)),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => context.push('/movies/${movie.id}'),
                            icon: const Icon(Icons.info), label: const Text('상세보기'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: Text('인기 영화', style: theme.textTheme.headlineMedium)),
            TextButton(onPressed: () => context.go('/movies'),
              child: const Text('전체보기 ›')),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            height: 320,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: movies.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) => SizedBox(
                width: 164, child: MovieCard(movie: movies[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Guided Practice의 공통 카드. 홈과 목록에서 모두 사용합니다.
class MovieCard extends StatelessWidget {
  const MovieCard({super.key, required this.movie});
  final Movie movie;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/movies/${movie.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(borderRadius: BorderRadius.circular(12),
                  child: Image.asset(movie.posterAsset, fit: BoxFit.cover)),
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: theme.colorScheme.scrim,
                      borderRadius: BorderRadius.circular(8)),
                    child: Text('★ ${movie.averageRating.toStringAsFixed(1)}',
                      style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.onPrimary)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(movie.title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
          Text('${movie.year} · ${movie.genre}', maxLines: 1,
            overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class MovieListScreen extends StatefulWidget {
  const MovieListScreen({
    super.key,
    this.initialMode = MovieLoadMode.success,
  });

  final MovieLoadMode initialMode;
  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  final movieService = const FakeMovieService();
  final genrePreference = GenrePreference();
  late Future<List<Movie>> _moviesFuture;

  String selectedGenre = '전체';
  bool _isSavingGenre = false;

  @override
  void initState() {
    super.initState();

    _moviesFuture = _loadMovies(mode: widget.initialMode);
  }

  Future<List<Movie>> _loadMovies({
    MovieLoadMode mode = MovieLoadMode.success,
  }) async {
    // 서로 독립적인 영화 조회와 장르 읽기를 함께 기다립니다.
    // 둘 중 하나가 실패하면 FutureBuilder의 Error 화면에서 재시도합니다.
    final results = await Future.wait<Object>([
      movieService.fetchMovies(mode: mode),
      genrePreference.read(),
    ]);
    final loadedMovies = results[0] as List<Movie>;
    final savedGenre = results[1] as String;

    if (!mounted) return loadedMovies;
    setState(() {
      selectedGenre = genres.contains(savedGenre) ? savedGenre : '전체';
    });
    return loadedMovies;
  }

  void _retry() {
    setState(() {
      // 실패 모드는 첫 요청에만 적용해 Error → Loading → Success를 확인합니다.
      _moviesFuture = _loadMovies();
    });
  }

  Future<void> _selectGenre(String genre) async {
    if (_isSavingGenre || selectedGenre == genre) return;
    final previousGenre = selectedGenre;

    setState(() {
      selectedGenre = genre;
      _isSavingGenre = true;
    });

    try {
      await genrePreference.save(genre);
    } catch (_) {
      if (!mounted) return;
      setState(() => selectedGenre = previousGenre);
      showNotice(context, '장르를 저장하지 못했습니다. 다시 선택해주세요.');
    } finally {
      if (mounted) {
        setState(() => _isSavingGenre = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('영화')),
      body: FutureBuilder<List<Movie>>(
        // build에서는 새 Future를 만들지 않고 준비한 Future를 사용합니다.
        future: _moviesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const MovieListLoading();
          }
          if (snapshot.hasError) {
            return MovieListError(onRetry: _retry);
          }

          final loadedMovies = snapshot.data ?? const <Movie>[];
          final filteredMovies = loadedMovies
              .where(
                (movie) =>
                    selectedGenre == '전체' || movie.genre == selectedGenre,
              )
              .toList();

          return Column(
            children: [
              SizedBox(
                height: 60,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: genres.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) => ChoiceChip(
                    label: Text(genres[index]),
                    selected: selectedGenre == genres[index],
                    showCheckmark: false,
                    // 저장 중 연속 입력을 막아 저장 순서가 뒤바뀌지 않게 합니다.
                    onSelected: _isSavingGenre
                        ? null
                        : (_) => _selectGenre(genres[index]),
                  ),
                ),
              ),
              Expanded(
                child: filteredMovies.isEmpty
                    ? const MovieListEmpty()
                    : MovieGrid(movies: filteredMovies),
              ),
            ],
          );
        },
      ),
    );
  }
}

// 3주차의 GridView를 그대로 옮겨 성공 상태에서 재사용합니다.
class MovieGrid extends StatelessWidget {
  const MovieGrid({super.key, required this.movies});

  final List<Movie> movies;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: movies.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 20,
        childAspectRatio: 0.58,
      ),
      itemBuilder: (context, index) => MovieCard(movie: movies[index]),
    );
  }
}

class MovieListLoading extends StatelessWidget {
  const MovieListLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('영화를 불러오는 중입니다.'),
        ],
      ),
    );
  }
}

class MovieListEmpty extends StatelessWidget {
  const MovieListEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('조건에 맞는 영화가 없습니다.'));
  }
}

class MovieListError extends StatelessWidget {
  const MovieListError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 40),
            const SizedBox(height: 12),
            const Text('영화를 불러오지 못했습니다.', textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('잠시 후 다시 시도해주세요.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key, required this.movie});
  final Movie movie;
  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  bool isFavorite = false;
  double? myRating;

  Future<void> openRatingDialog() async {
    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) => RatingDialog(initialRating: myRating ?? 0),
    );
    if (!mounted || result == null) return;
    setState(() => myRating = result);
  }

  void toggleFavorite() {
    setState(() => isFavorite = !isFavorite);
    showNotice(context, isFavorite ? '즐겨찾기에 추가했습니다.' : '즐겨찾기에서 삭제했습니다.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final movie = widget.movie;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Cinema Archive'),
        leading: IconButton(
          tooltip: '뒤로가기', icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/movies');
            }
          },
        ),
        actions: const [IconButton(tooltip: '공유', icon: Icon(Icons.share),
          onPressed: null)],
      ),
      body: ListView(
        children: [
          AspectRatio(aspectRatio: 2 / 3,
            child: Image.asset(movie.posterAsset, fit: BoxFit.cover)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(movie.title, style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text('${movie.year} · ${movie.genre} · ${movie.minutes}분'),
                const SizedBox(height: 16),
                Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    RatingBarIndicator(
                      rating: movie.averageRating,
                      itemCount: 5, itemSize: 24,
                      itemBuilder: (context, index) => Icon(Icons.star,
                        color: theme.colorScheme.primary),
                    ),
                    Text(movie.averageRating.toStringAsFixed(1)),
                  ],
                ),
                const SizedBox(height: 16),
                Chip(label: Text(movie.genre)),
                if (myRating != null)
                  Padding(padding: const EdgeInsets.only(top: 12),
                    child: Text('내 평점: ${myRating!.toStringAsFixed(1)}점')),
                const Divider(height: 40),
                Text('시놉시스', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 16),
                Text(movie.synopsis, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: toggleFavorite,
              icon: Icon(isFavorite ? Icons.bookmark : Icons.bookmark_outline),
              label: Text(isFavorite ? '즐겨찾기 해제' : '즐겨찾기'),
            )),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton.icon(
              onPressed: openRatingDialog,
              icon: const Icon(Icons.rate_review_outlined),
              label: const Text('평점 남기기'),
            )),
          ]),
        ),
      ),
    );
  }
}

class MovieRatingInput extends StatelessWidget {
  const MovieRatingInput({super.key, required this.rating, required this.onChanged});
  final double rating;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return RatingBar.builder(
      initialRating: rating, minRating: 0.5, allowHalfRating: true,
      itemCount: 5, itemSize: 36,
      itemBuilder: (context, index) => Icon(Icons.star,
        color: Theme.of(context).colorScheme.primary),
      onRatingUpdate: onChanged,
    );
  }
}

class RatingDialog extends StatefulWidget {
  const RatingDialog({super.key, required this.initialRating});
  final double initialRating;
  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  late double rating;

  @override
  void initState() {
    super.initState();
    rating = widget.initialRating;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('영화는 어떠셨나요?', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: MovieRatingInput(
                rating: rating,
                onChanged: (value) => setState(() => rating = value),
              ),
            ),
            const SizedBox(height: 16),
            Text(rating == 0 ? '별점을 선택해주세요.' : '${rating.toStringAsFixed(1)}점'),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('취소'),
              )),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton(
                onPressed: rating > 0
                  ? () => Navigator.of(context).pop(rating) : null,
                child: const Text('저장'),
              )),
            ]),
          ],
        ),
      ),
    );
  }
}

class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('내 프로필')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 24),
          Center(child: CircleAvatar(
            radius: 66, backgroundColor: theme.colorScheme.primaryContainer,
            child: const CircleAvatar(radius: 62,
              backgroundImage: AssetImage('assets/images/profile/profile_movielog.jpg')),
          )),
          const SizedBox(height: 20),
          Text('무비러버', textAlign: TextAlign.center, style: theme.textTheme.headlineLarge),
          const SizedBox(height: 12),
          Text('매주 주말엔 영화관으로 출근하는 프로 관람객. 좋은 영화를 보고 기록하는 것을 좋아합니다.',
            textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 24),
          Center(child: OutlinedButton(
            onPressed: null,
            child: const Text('프로필 수정'),
          )),
          const SizedBox(height: 24),
          const Row(children: [
            Expanded(child: ProfileStat(label: '본 영화', value: '342')),
            SizedBox(width: 8),
            Expanded(child: ProfileStat(label: '평점', value: '4.2')),
            SizedBox(width: 8),
            Expanded(child: ProfileStat(label: '즐겨찾기', value: '58')),
          ]),
          const SizedBox(height: 32),
          Text('선호하는 장르', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 12),
          const Wrap(spacing: 8, children: [
            Chip(label: Text('드라마')), Chip(label: Text('SF')),
            Chip(label: Text('애니메이션')),
          ]),
        ],
      ),
    );
  }
}

class ProfileStat extends StatelessWidget {
  const ProfileStat({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 4),
      decoration: BoxDecoration(color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Text(label, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
        Text(value, style: theme.textTheme.headlineLarge),
      ]),
    );
  }
}

class MovieNotFoundScreen extends StatelessWidget {
  const MovieNotFoundScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('영화를 찾을 수 없습니다'), automaticallyImplyLeading: false),
      body: Center(child: ElevatedButton(
        onPressed: () => context.go('/movies'), child: const Text('영화 목록으로'),
      )),
    );
  }
}
