import 'package:dio/dio.dart';

import '../storage/token_storage.dart';
import 'auth_interceptor.dart';

BaseOptions _movieLogOptions() => BaseOptions(
  baseUrl: 'https://workbook.devnoco.com',
  connectTimeout: const Duration(seconds: 10),
  receiveTimeout: const Duration(seconds: 10),
);
Dio createMovieLogClient() => Dio(_movieLogOptions());
Dio createAuthMovieLogClient(
  TokenStorage storage,
  int Function() sessionVersion,
) =>
    Dio(_movieLogOptions())
      ..interceptors.add(AuthInterceptor(storage, sessionVersion));
