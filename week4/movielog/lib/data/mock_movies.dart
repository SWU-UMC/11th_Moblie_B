import '../models/movie.dart';

/// 홈·목록·상세가 모두 같은 Mock Data를 읽습니다. (실제 API 연결 없음)
const movies = [
  Movie(
    id: 1,
    title: '별빛 아래 우리',
    genres: ['로맨스', '드라마'],
    year: 2024,
    runtimeMinutes: 124,
    averageRating: 4.5,
    ratingCount: 1245,
    posterAsset: 'assets/images/posters/hero_under_the_starlight.jpg',
    synopsis:
        '바쁜 현대 사회 속에서 서로의 존재를 잊고 살아가던 두 남녀가 우연한 계기로 '
        '작은 천문대에서 만나게 됩니다. 매일 밤 별을 관측하며 서로의 상처를 치유하고, '
        '잊고 있던 꿈과 사랑을 다시금 깨닫게 되는 따뜻한 이야기입니다.\n\n'
        '별이 쏟아지는 밤하늘 아래, 그들이 나눈 조용한 약속들은 과연 영원할 수 '
        '있을까요? 눈부신 영상미와 감성적인 OST가 어우러져 깊은 여운을 남기는 '
        '올 겨울 최고의 로맨스 영화.',
  ),
  Movie(
    id: 2,
    title: '우주의 끝에서',
    genres: ['SF'],
    year: 2024,
    runtimeMinutes: 138,
    averageRating: 4.2,
    ratingCount: 980,
    posterAsset: 'assets/images/posters/poster_echoes_of_the_void.jpg',
    synopsis:
        '마지막 신호가 끊긴 탐사선을 찾아 우주의 끝으로 향한 우주비행사가 '
        '고요한 공허 속에서 인류의 기원에 관한 비밀과 마주합니다.',
  ),
  Movie(
    id: 3,
    title: '기억의 숲',
    genres: ['애니메이션', '판타지'],
    year: 2022,
    runtimeMinutes: 102,
    averageRating: 4.9,
    ratingCount: 2310,
    posterAsset: 'assets/images/posters/poster_whispering_woods.jpg',
    synopsis:
        '속삭이는 나무들이 사는 숲에 길을 잃은 소녀가 들어서며, 잊혀진 기억을 '
        '되찾기 위한 신비로운 여정이 시작됩니다.',
  ),
  Movie(
    id: 4,
    title: '밤의 그림자',
    genres: ['스릴러'],
    year: 2024,
    runtimeMinutes: 116,
    averageRating: 3.8,
    ratingCount: 640,
    posterAsset: 'assets/images/posters/poster_night_shadows.jpg',
    synopsis:
        '비 내리는 도시의 골목에서 연이어 사라지는 사람들. 밤에만 움직이는 '
        '그림자를 쫓는 형사가 사건의 진실에 가까워질수록 위험도 커져 갑니다.',
  ),
  Movie(
    id: 5,
    title: '봄날의 커피',
    genres: ['로맨스'],
    year: 2021,
    runtimeMinutes: 109,
    averageRating: 4.5,
    ratingCount: 1102,
    posterAsset: 'assets/images/posters/poster_fourth_afternoon.jpg',
    synopsis:
        '매주 같은 시간 같은 카페를 찾는 두 사람. 커피 한 잔으로 시작된 대화가 '
        '네 번째 오후에 특별한 이야기로 바뀝니다.',
  ),
  Movie(
    id: 6,
    title: '어비스 워커',
    genres: ['SF', '액션'],
    year: 2023,
    runtimeMinutes: 131,
    averageRating: 4.1,
    ratingCount: 870,
    posterAsset: 'assets/images/posters/poster_abyss_walker.jpg',
    synopsis:
        '붕괴된 행성의 심연을 걷는 구조대원이 고립된 생존자를 찾아 '
        '마지막 임무에 나섭니다.',
  ),
];

/// 홈 상단에 보여줄 추천 영화
Movie get featuredMovie => movies.first;

/// 평균 평점이 높은 순서의 인기 영화
List<Movie> get popularMovies =>
    [...movies]..sort((a, b) => b.averageRating.compareTo(a.averageRating));

/// Mock Data에 있는 모든 장르 (중복 제거, 등장 순서 유지)
List<String> get allGenres =>
    {for (final movie in movies) ...movie.genres}.toList();

Movie? findMovieById(int? id) {
  for (final movie in movies) {
    if (movie.id == id) return movie;
  }
  return null;
}

/// 선택한 장르 중 하나라도 포함하는 영화. 선택이 없으면 전체 목록
List<Movie> filterMoviesByGenres(Set<String> genres) =>
    filterMoviesInList(movies, genres);

/// 비동기로 불러온 [source] 목록에서 장르로 거릅니다.
List<Movie> filterMoviesInList(List<Movie> source, Set<String> genres) {
  if (genres.isEmpty) return source;
  return source.where((movie) => movie.genres.any(genres.contains)).toList();
}
