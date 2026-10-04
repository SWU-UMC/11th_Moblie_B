// 홈, 영화 목록, 상세에서 같은 데이터를 사용합니다.
class Movie {
  const Movie({
    required this.id,
    required this.title,
    required this.genre,
    required this.year,
    required this.posterAsset,
    required this.minutes,
    required this.averageRating,
    required this.synopsis,
  });

  final int id;
  final String title;
  final String genre;
  final int year;
  final String posterAsset;
  final int minutes;
  final double averageRating;
  final String synopsis;
}

const movies = [
  Movie(
    id: 1,
    title: '별빛 아래 우리',
    genre: '드라마',
    year: 2024,
    posterAsset: 'assets/images/posters/hero_under_the_starlight.jpg',
    minutes: 124,
    averageRating: 4.5,
    synopsis: '바쁜 현대 사회 속에서 서로의 존재를 잊고 살아가던 두 남녀가 우연한 계기로 작은 천문대에서 만나게 됩니다. 매일 밤 별을 관측하며 서로의 상처를 치유하고, 잊고 있던 꿈과 사랑을 다시금 깨닫게 되는 따뜻한 이야기입니다.\n\n과거의 아픔으로 인해 사람에게 마음을 열지 못하던 여주인공은, 별자리처럼 변함없는 모습으로 자신을 기다려주는 남주인공을 통해 서서히 마음의 문을 열게 됩니다. 하지만 두 사람 앞에 놓인 현실적인 장벽들은 그들의 관계를 시험하게 되는데…\n\n별이 쏟아지는 밤하늘 아래, 그들이 나눈 조용한 약속들은 과연 영원할 수 있을까요?',
  ),
  Movie(
    id: 2,
    title: '우주의 끝에서',
    genre: 'SF',
    year: 2024,
    posterAsset: 'assets/images/posters/poster_echoes_of_the_void.jpg',
    minutes: 118,
    averageRating: 4.2,
    synopsis: '미지의 행성에서 들려온 신호를 따라간 탐사대가 인류의 기억과 마주하는 이야기입니다.',
  ),
  Movie(
    id: 3,
    title: '기억의 숲',
    genre: '애니메이션',
    year: 2023,
    posterAsset: 'assets/images/posters/poster_whispering_woods.jpg',
    minutes: 102,
    averageRating: 4.9,
    synopsis: '잃어버린 기억을 찾아 신비로운 숲으로 들어간 소녀가 새로운 친구들을 만납니다.',
  ),
  Movie(
    id: 4,
    title: '밤의 그림자',
    genre: '스릴러',
    year: 2024,
    posterAsset: 'assets/images/posters/poster_night_shadows.jpg',
    minutes: 110,
    averageRating: 3.8,
    synopsis: '잠들지 않는 도시에서 사라진 사람들의 흔적을 쫓는 형사의 이야기입니다.',
  ),
  Movie(
    id: 5,
    title: '심연을 걷는 자',
    genre: '액션',
    year: 2024,
    posterAsset: 'assets/images/posters/poster_abyss_walker.jpg',
    minutes: 126,
    averageRating: 4.1,
    synopsis: '도시 아래 숨겨진 비밀을 밝히기 위해 위험한 여정을 시작합니다.',
  ),
  Movie(
    id: 6,
    title: '네 번째 오후',
    genre: '드라마',
    year: 2023,
    posterAsset: 'assets/images/posters/poster_fourth_afternoon.jpg',
    minutes: 98,
    averageRating: 4.0,
    synopsis: '매주 같은 시간에 만나는 두 사람이 일상의 작은 변화를 함께 만들어 갑니다.',
  ),
];

const genres = ['전체', '드라마', 'SF', '애니메이션', '스릴러', '액션'];

Movie? findMovieById(int? id) {
  for (final movie in movies) {
    if (movie.id == id) return movie;
  }
  return null;
}
