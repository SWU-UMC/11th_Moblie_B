import '../models/movie.dart';

// 실제 서버 대신 사용하는 Mock Data입니다. 홈, 목록, 상세가 모두 이 목록을 참조합니다.
const mockMovies = <Movie>[
  Movie(
    id: 'under-the-starlight',
    title: '별빛 아래 우리',
    genres: ['로맨스', '드라마'],
    year: 2024,
    runtimeMinutes: 124,
    posterPath: 'assets/images/posters/hero_under_the_starlight.jpg',
    rating: 4.5,
    reviewCount: 1245,
    tags: ['로맨스', '드라마', '감동적인'],
    synopsis:
        '바쁜 현대 사회 속에서 서로의 존재를 잊고 살아가던 두 남녀가 우연한 계기로 '
        '작은 천문대에서 만나게 됩니다. 매일 밤 별을 관측하며 서로의 상처를 치유하고, '
        '잊고 있던 꿈과 사랑을 다시금 깨닫게 되는 따뜻한 이야기입니다.\n\n'
        '과거의 아픔으로 인해 사람에게 마음을 열지 못하던 여주인공은, 별자리처럼 '
        '변함없는 모습으로 자신을 기다려주는 남주인공을 통해 서서히 마음의 문을 열게 '
        '됩니다. 하지만 두 사람 앞에 놓인 현실적인 장벽들은 그들의 관계를 시험하게 '
        '되는데...\n\n'
        '별이 쏟아지는 밤하늘 아래, 그들이 나눈 조용한 약속들은 과연 영원할 수 '
        '있을까요? 눈부신 영상미와 감성적인 OST가 어우러져 깊은 여운을 남기는 올 '
        '겨울 최고의 로맨스 영화.\n\n'
        '잔잔한 감동과 함께 삶의 의미를 다시 한번 되돌아보게 만드는 수작입니다.',
  ),
  Movie(
    id: 'echoes-of-the-void',
    title: '우주의 끝에서',
    genres: ['SF'],
    year: 2024,
    runtimeMinutes: 132,
    posterPath: 'assets/images/posters/poster_echoes_of_the_void.jpg',
    rating: 4.2,
    reviewCount: 982,
    tags: ['SF', '우주'],
  ),
  Movie(
    id: 'whispering-woods',
    title: '기억의 숲',
    genres: ['애니메이션'],
    year: 2024,
    runtimeMinutes: 98,
    posterPath: 'assets/images/posters/poster_whispering_woods.jpg',
    rating: 4.9,
    reviewCount: 2310,
    tags: ['애니메이션', '판타지'],
  ),
  Movie(
    id: 'night-shadows',
    title: '밤의 그림자',
    genres: ['스릴러'],
    year: 2024,
    runtimeMinutes: 115,
    posterPath: 'assets/images/posters/poster_night_shadows.jpg',
    rating: 3.8,
    reviewCount: 640,
    tags: ['스릴러', '누아르'],
  ),
  Movie(
    id: 'fourth-afternoon',
    title: '네 번째 오후',
    genres: ['드라마', '로맨스'],
    year: 2024,
    runtimeMinutes: 108,
    posterPath: 'assets/images/posters/poster_fourth_afternoon.jpg',
    rating: 4.3,
    reviewCount: 871,
    tags: ['드라마', '잔잔한'],
  ),
  Movie(
    id: 'mission-improbable',
    title: '미션 임프로버블',
    genres: ['코미디'],
    year: 2024,
    runtimeMinutes: 112,
    posterPath: 'assets/images/posters/poster_abyss_walker.jpg',
    rating: 4.0,
    reviewCount: 1530,
    tags: ['코미디', '액션'],
  ),
];

/// 영화 목록의 장르 Chip 순서입니다. '전체'는 필터를 적용하지 않습니다.
const allGenresLabel = '전체';
const movieGenres = [allGenresLabel, '드라마', 'SF', '애니메이션', '스릴러', '로맨스', '코미디'];

List<Movie> moviesByGenre(String genre) {
  if (genre == allGenresLabel) return mockMovies;
  return mockMovies.where((movie) => movie.genres.contains(genre)).toList();
}

Movie? findMovieById(String id) {
  for (final movie in mockMovies) {
    if (movie.id == id) return movie;
  }
  return null;
}
