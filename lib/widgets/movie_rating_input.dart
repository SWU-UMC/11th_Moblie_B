import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class MovieRatingInput extends StatelessWidget {
  const MovieRatingInput({
    super.key,
    required this.rating,
    required this.onChanged,
    this.enabled = true,
  });
  final double rating;
  final ValueChanged<double> onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) => RatingBar.builder(
    initialRating: rating,
    minRating: 1,
    allowHalfRating: false,
    ignoreGestures: !enabled,
    itemCount: 5,
    itemSize: 40,
    itemBuilder: (context, index) =>
        Icon(Icons.star, color: Theme.of(context).colorScheme.primary),
    onRatingUpdate: onChanged,
  );
}
