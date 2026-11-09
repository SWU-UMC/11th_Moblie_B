import 'package:flutter/material.dart';

/// 목록을 불러오는 동안 빈 화면 대신 보여주는 Loading 상태입니다.
class MovieLoadingView extends StatelessWidget {
  const MovieLoadingView({super.key, this.message = '영화 목록을 불러오고 있어요'});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            message,
            style: textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
