import 'package:dio/dio.dart';
import 'package:ejioji/core/network/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';

/// The backend answers every error as `{"error": {"code", "message"}}`. These
/// pin that the app reads that shape, because the first version looked for a
/// top-level `detail` and so never showed a single server message.
DioException _error(
  int status,
  Object? body, {
  Map<String, List<String>> headers = const {},
}) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<Object?>(
      requestOptions: options,
      statusCode: status,
      data: body,
      headers: Headers.fromMap(headers),
    ),
  );
}

void main() {
  test("the server's message and code reach the person", () {
    final e = ApiException.from(
      _error(409, {
        'error': {'code': 'conflict', 'message': 'That name is taken.'},
      }),
    );
    expect(e, isA<ValidationFailure>());
    expect(e.message, 'That name is taken.');
    expect(e.code, 'conflict');
  });

  test('a rate limit carries the wait the server asked for', () {
    final e = ApiException.from(
      _error(
        429,
        {
          'error': {'code': 'rate_limited', 'message': 'Too many codes requested.'},
        },
        headers: {
          'retry-after': ['42'],
        },
      ),
    );
    expect(e, isA<RateLimitedFailure>());
    expect(e.message, 'Too many codes requested.');
    expect((e as RateLimitedFailure).retryAfter, const Duration(seconds: 42));
  });

  test('a 401 keeps what the server said, for the sign-in screen', () {
    final e = ApiException.from(
      _error(401, {
        'error': {'code': 'unauthenticated', 'message': 'That code is not valid.'},
      }),
    );
    expect(e, isA<UnauthorisedFailure>());
    expect((e as UnauthorisedFailure).serverMessage, 'That code is not valid.');
    expect(WrongCodeFailure(e.serverMessage).message, 'That code is not valid.');
  });

  test("FastAPI's own validation list falls back to the generic line", () {
    final e = ApiException.from(
      _error(422, {
        'detail': [
          {'loc': ['body', 'phone'], 'msg': 'field required'},
        ],
      }),
    );
    expect(e, isA<ValidationFailure>());
    expect(e.message, 'That did not go through. Have another look.');
  });

  test('a 5xx body is never shown', () {
    final e = ApiException.from(
      _error(500, {
        'error': {'code': 'internal', 'message': 'Traceback (most recent call last)'},
      }),
    );
    expect(e, isA<ServerFailure>());
    expect(e.message, isNot(contains('Traceback')));
  });

  test('an overlong message is not pushed into the UI', () {
    final e = ApiException.from(
      _error(400, {
        'error': {'code': 'bad_request', 'message': 'x' * 500},
      }),
    );
    expect(e.message, 'That did not go through. Have another look.');
  });
}
