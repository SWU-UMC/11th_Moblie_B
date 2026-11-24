import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import 'core/network/movie_log_client.dart';
import 'core/network/tmdb_client.dart';
import 'core/storage/token_storage.dart';
import 'data/services/auth_api_service.dart';
import 'data/services/member_api_service.dart';
import 'data/services/sign_up_service.dart';
import 'data/services/rating_api_service.dart';
import 'data/services/tmdb_movie_service.dart';
import 'view_models/auth_view_model.dart';
import 'view_models/my_ratings_view_model.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const MovieLogApp());
}

class MovieLogApp extends StatefulWidget {
  const MovieLogApp({super.key});
  @override
  State<MovieLogApp> createState() => _MovieLogAppState();
}

class _MovieLogAppState extends State<MovieLogApp> {
  late final TokenStorage _storage;
  late final Dio _publicClient;
  late final Dio _authClient;
  AuthViewModel? _authSession;
  @override
  void initState() {
    super.initState();
    _storage = SecureTokenStorage(const FlutterSecureStorage());
    _publicClient = createMovieLogClient();
    _authClient = createAuthMovieLogClient(
      _storage,
      () => _authSession?.sessionVersion ?? 0,
    );
  }

  @override
  void dispose() {
    _publicClient.close(force: true);
    _authClient.close(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      Provider<TokenStorage>.value(value: _storage),
      Provider<AuthApiService>(create: (_) => AuthApiService(_publicClient)),
      Provider<MemberApiService>(create: (_) => MemberApiService(_authClient)),
      Provider<SignUpService>(create: (_) => SignUpService(_publicClient)),
      Provider<RatingApiService>(
        create: (_) => RatingApiService(_publicClient, _authClient),
      ),
      Provider<TmdbMovieService>(
        create: (_) => TmdbMovieService(createTmdbClient()),
      ),
      ChangeNotifierProvider<AuthViewModel>(
        create: (context) => _authSession = AuthViewModel(
          context.read<AuthApiService>(),
          context.read<MemberApiService>(),
          _storage,
        ),
      ),
      ChangeNotifierProvider<MyRatingsViewModel>(
        lazy: false,
        create: (context) => MyRatingsViewModel(
          context.read<RatingApiService>(),
          context.read<AuthViewModel>(),
        ),
      ),
    ],
    child: const _MovieLogRouterApp(),
  );
}

class _MovieLogRouterApp extends StatefulWidget {
  const _MovieLogRouterApp();
  @override
  State<_MovieLogRouterApp> createState() => _MovieLogRouterAppState();
}

class _MovieLogRouterAppState extends State<_MovieLogRouterApp> {
  late final GoRouter _router;
  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthViewModel>();
    _router = AppRouter.createRouter(auth);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) auth.restoreSession();
    });
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    debugShowCheckedModeBanner: false,
    title: 'MovieLog',
    theme: AppTheme.lightTheme,
    routerConfig: _router,
  );
}
