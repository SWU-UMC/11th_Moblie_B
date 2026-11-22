import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../data/services/tmdb_movie_service.dart';
import '../view_models/my_ratings_view_model.dart';
import '../view_models/auth_view_model.dart';
import '../view_models/movie_detail_view_model.dart';
import '../movie_screens.dart';

class MovieDetailLoader extends StatefulWidget {
  const MovieDetailLoader({
    super.key,
    required this.movieId,
    this.initialMovie,
  });
  final int movieId;
  final TmdbMovieDto? initialMovie;
  @override
  State<MovieDetailLoader> createState() => _MovieDetailLoaderState();
}

class _MovieDetailLoaderState extends State<MovieDetailLoader> {
  late final Future<TmdbMovieDto> _movieFuture;
  @override
  void initState() {
    super.initState();
    _movieFuture = widget.initialMovie != null
        ? Future.value(widget.initialMovie!)
        : context.read<TmdbMovieService>().fetchMovieDetail(widget.movieId);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<TmdbMovieDto>(
    future: _movieFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError || snapshot.data == null) {
        return const MovieNotFoundScreen();
      }
      return ChangeNotifierProvider(
        create: (context) => MovieDetailViewModel(
          context.read<MyRatingsViewModel>(),
          context.read<AuthViewModel>(),
          snapshot.data!,
        ),
        child: const MovieDetailScreen(),
      );
    },
  );
}
