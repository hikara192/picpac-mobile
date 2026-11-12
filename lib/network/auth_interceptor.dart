import 'package:dio/dio.dart';

import 'token_store.dart';

Interceptor authInterceptor(TokenStore tokens) => InterceptorsWrapper(
  onRequest: (options, handler) {
    final token = tokens.session?.token;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  },
);
