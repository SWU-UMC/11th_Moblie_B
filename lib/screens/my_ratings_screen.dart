import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_models/my_ratings_view_model.dart';
import '../widgets/tmdb_poster_image.dart';
import '../widgets/movielog_button.dart';

class MyRatingsScreen extends StatelessWidget {
  const MyRatingsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const BackButton(),
      centerTitle: true,
      title: const Text('내가 등록한 평점'),
    ),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('학습용 회원 1번의 공개 평점입니다.'),
        ),
        Expanded(
          child: Consumer<MyRatingsViewModel>(
            builder: (context, vm, child) {
              return switch (vm.status) {
                MyRatingsLoadStatus.idle || MyRatingsLoadStatus.loading =>
                  const Center(child: CircularProgressIndicator()),
                MyRatingsLoadStatus.empty => const Center(
                  child: Text('아직 등록된 평점이 없습니다.'),
                ),
                MyRatingsLoadStatus.error => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(vm.message ?? '평점을 불러오지 못했습니다.'),
                        const SizedBox(height: 16),
                        MovieLogButton(
                          label: '다시 시도',
                          width: 120,
                          onPressed: vm.load,
                        ),
                      ],
                    ),
                  ),
                ),
                MyRatingsLoadStatus.success => ListView(
                  children: [
                    if (vm.message != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(vm.message!),
                      ),
                    ...vm.ratings.map(
                      (entry) => Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TmdbPosterImage(
                                posterPath: entry.movie?.posterPath,
                                width: 80,
                                height: 120,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.movie?.title ?? '영화 정보를 찾을 수 없습니다.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    Text('영화 ID: ${entry.rating.movieId}'),
                                    Text('★ ${entry.rating.score} / 5'),
                                    if (entry.rating.comment != null)
                                      Text(entry.rating.comment!),
                                    Text(
                                      '등록일: ${entry.rating.createdAt.toLocal().toIso8601String().substring(0, 10)}',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              };
            },
          ),
        ),
      ],
    ),
  );
}
