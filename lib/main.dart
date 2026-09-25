import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';

void main() => runApp(MovieLogApp());

final _appRouter = createAppRouter();

class MovieLogApp extends StatelessWidget {
  MovieLogApp({super.key, GoRouter? router}) : router = router ?? _appRouter;

  final GoRouter router;

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    routerConfig: router,
  );
}
