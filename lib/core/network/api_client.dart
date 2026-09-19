import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../storage/token_store.dart';
import 'api_exception.dart';
import 'endpoints.dart';
import 'json.dart';

/// The only thing in the app that talks to our API.
///
/// Repositories call this; widgets never do. It attaches the bearer token,
/// refreshes it once on a 401, and turns every transport failure into an
/// [ApiException] so no screen ever has to know what Dio is.
class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  /// A single object, for an endpoint that returns one.
  Future<Json> getJson(String path, {Map<String, Object?>? query}) async =>
      asJson(await _body(() => _dio.get<Object?>(path, queryParameters: query)));

  /// A bare list, for the handful of endpoints that return one at the top
  /// level (notices, grants, candidates, connections, media).
  Future<List<Json>> getList(String path, {Map<String, Object?>? query}) async =>
      asJsonList(
        await _body(() => _dio.get<Object?>(path, queryParameters: query)),
      );

  /// [anonymous] is for the calls made before anyone is signed in (asking for
  /// and checking a code): no bearer is sent, and a 401 is passed through as
  /// the answer rather than taken as a session to refresh.
  Future<Json> post(String path, {Object? body, bool anonymous = false}) async =>
      asJson(
        await _body(
          () => _dio.post<Object?>(
            path,
            data: body,
            options: anonymous ? Options(extra: {'anonymous': true}) : null,
          ),
        ),
      );

  Future<List<Json>> postList(String path, {Object? body}) async =>
      asJsonList(await _body(() => _dio.post<Object?>(path, data: body)));

  Future<Json> put(String path, {Object? body}) async =>
      asJson(await _body(() => _dio.put<Object?>(path, data: body)));

  Future<List<Json>> putList(String path, {Object? body}) async =>
      asJsonList(await _body(() => _dio.put<Object?>(path, data: body)));

  /// For the endpoints that answer 204. Calling one of the body-returning
  /// methods on these would throw on the empty body, which is why they are
  /// separate rather than nullable.
  Future<void> postEmpty(String path, {Object? body}) =>
      _run(() => _dio.post<Object?>(path, data: body));

  Future<void> putEmpty(String path, {Object? body}) =>
      _run(() => _dio.put<Object?>(path, data: body));

  Future<void> deleteEmpty(String path, {Object? body}) =>
      _run(() => _dio.delete<Object?>(path, data: body));

  /// Raw bytes with an explicit content type, for the Netflix CSV, which is
  /// posted as the request body rather than as a form.
  Future<Json> postRaw(
    String path, {
    required Object body,
    required String contentType,
  }) async =>
      asJson(
        await _body(
          () => _dio.post<Object?>(
            path,
            data: body,
            options: Options(contentType: contentType),
          ),
        ),
      );

  Future<Object?> _body(Future<Response<Object?>> Function() call) async {
    final res = await _run(call);
    final data = res.data;
    if (data == null) {
      throw const UnknownFailure(debugDetail: 'empty body where one was due');
    }
    return data;
  }

  Future<Response<Object?>> _run(
    Future<Response<Object?>> Function() call,
  ) async {
    try {
      return await call();
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
            debugPrint('-> ${o.method} ${o.path}');
            h.next(o);
          },
          onError: (e, h) {
            debugPrint('x  ${e.requestOptions.path} ${e.response?.statusCode}');
            h.next(e);
          },
        ),
      );
    }

    return ApiClient(dio);
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
    final wasAnonymous = err.requestOptions.extra['anonymous'] == true;

    // Signing in with a wrong code is a 401 that means "wrong code", not
    // "your session ended". Refreshing on it would be nonsense, and would
    // hand the OTP screen the wrong error to show.
    if (!is401 || alreadyRetried || isRefreshCall || wasAnonymous) {
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
      final res = await _dio.post<Object?>(
        Api.refresh,
        data: {'refresh_token': refresh},
        options: Options(extra: {'anonymous': true, 'refresh': true}),
      );
      final data = res.data;
      if (data is! Map) return null;
      final access = data['access_token'];
      final next = data['refresh_token'];
      if (access is! String) return null;
      // The backend rotates refresh tokens, so store whichever it returned.
      await _tokens.save(
        access: access,
        refresh: next is String ? next : refresh,
      );
      return access;
    } on DioException {
      await _tokens.clear();
      return null;
    }
  }
}
