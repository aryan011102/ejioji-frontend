import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../storage/token_store.dart';
import 'api_exception.dart';

/// The only thing in the app that talks to the network.
///
/// Repositories call this; widgets never do. It attaches the bearer token,
/// refreshes it once on a 401, and turns every transport failure into an
/// [ApiException] so no screen ever has to know what Dio is.
class ApiClient {
  ApiClient(this._dio, {required this.onSessionLost});

  final Dio _dio;

  /// Called when a refresh is refused. The session controller listens and
  /// sends the app back to sign-in; the client itself does not navigate.
  final Future<void> Function() onSessionLost;

  Future<T> get<T>(String path, {Map<String, Object?>? query}) =>
      _send(() => _dio.get<T>(path, queryParameters: query));

  Future<T> post<T>(String path, {Object? body}) =>
      _send(() => _dio.post<T>(path, data: body));

  Future<T> patch<T>(String path, {Object? body}) =>
      _send(() => _dio.patch<T>(path, data: body));

  Future<T> delete<T>(String path, {Object? body}) =>
      _send(() => _dio.delete<T>(path, data: body));

  Future<T> _send<T>(Future<Response<T>> Function() call) async {
    try {
      final res = await call();
      final data = res.data;
      if (data == null) {
        throw const UnknownFailure(debugDetail: 'empty body');
      }
      return data;
    } on DioException catch (e) {
      throw ApiException.from(e);
    }
  }

  static ApiClient build(Ref ref, {required Future<void> Function() onLost}) {
    final tokens = ref.watch(tokenStoreProvider);

    final dio = Dio(
      BaseOptions(
        baseUrl: Env.apiBaseUrl,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        headers: const {'Accept': 'application/json'},
        // 4xx and 5xx are exceptions, not data. Nothing downstream has to
        // remember to check a status code.
        validateStatus: (s) => s != null && s >= 200 && s < 300,
      ),
    );

    dio.interceptors.add(_AuthInterceptor(dio, tokens, onLost));

    // Logs are debug-only and never include headers or bodies: a request log
    // with an Authorization header in it is a leaked credential.
    if (kDebugMode) {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            debugPrint('→ ${o.method} ${o.path}');
            h.next(o);
          },
          onError: (e, h) {
            debugPrint('✗ ${e.requestOptions.path} ${e.response?.statusCode}');
            h.next(e);
          },
        ),
      );
    }

    return ApiClient(dio, onSessionLost: onLost);
  }
}

/// Attaches the token, and refreshes it exactly once per failure.
///
/// Concurrent 401s share one refresh: without the [_refreshing] latch, six
/// screens loading at once would fire six refreshes, and five of them would
/// present an already-rotated token and be refused.
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._dio, this._tokens, this._onLost);

  final Dio _dio;
  final TokenStore _tokens;
  final Future<void> Function() _onLost;

  Future<String?>? _refreshing;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra['anonymous'] != true) {
      final token = await _tokens.readAccess();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final is401 = err.response?.statusCode == 401;
    final alreadyRetried = err.requestOptions.extra['retried'] == true;
    final isRefreshCall = err.requestOptions.extra['refresh'] == true;

    if (!is401 || alreadyRetried || isRefreshCall) {
      return handler.next(err);
    }

    final fresh = await (_refreshing ??= _refresh());
    _refreshing = null;

    if (fresh == null) {
      await _onLost();
      return handler.next(err);
    }

    try {
      final options = err.requestOptions
        ..headers['Authorization'] = 'Bearer $fresh'
        ..extra['retried'] = true;
      final res = await _dio.fetch<Object?>(options);
      return handler.resolve(res);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  Future<String?> _refresh() async {
    final refresh = await _tokens.readRefresh();
    if (refresh == null) return null;
    try {
      final res = await _dio.post<Map<String, Object?>>(
        '/auth/refresh',
        data: {'refresh_token': refresh},
        options: Options(extra: {'anonymous': true, 'refresh': true}),
      );
      final access = res.data?['access_token'] as String?;
      final next = res.data?['refresh_token'] as String?;
      if (access == null) return null;
      // The backend rotates refresh tokens, so store whichever it returned.
      await _tokens.save(access: access, refresh: next ?? refresh);
      return access;
    } on DioException {
      await _tokens.clear();
      return null;
    }
  }
}
