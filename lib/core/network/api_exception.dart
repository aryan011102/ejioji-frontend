import 'package:dio/dio.dart';

/// One error type for the whole app.
///
/// Screens never see a [DioException]. They see this, and they show
/// [message] — which is written for a person and deliberately says nothing
/// about hosts, status codes or payloads. What actually went wrong is in
/// [debugDetail], which is logged in debug builds and dropped in release.
sealed class ApiException implements Exception {
  const ApiException(this.message, {this.debugDetail, this.code});

  final String message;
  final String? debugDetail;

  /// The server's machine-readable reason (`rate_limited`, `conflict`, ...),
  /// for the few screens that act on one. Null for transport failures.
  final String? code;

  @override
  String toString() => 'ApiException($message)';

  /// The one place a transport error becomes something a screen can render.
  static ApiException from(Object error) {
    if (error is ApiException) return error;
    if (error is! DioException) {
      return UnknownFailure(debugDetail: error.runtimeType.toString());
    }

    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        const TimeoutFailure(),
      // Added by Dio 5.7; a body that never finishes deserialising is, to a
      // person, the same thing as a slow connection.
      DioExceptionType.transformTimeout => const TimeoutFailure(),
      DioExceptionType.connectionError => const OfflineFailure(),
      DioExceptionType.badCertificate => const SecurityFailure(),
      DioExceptionType.cancel => const CancelledFailure(),
      DioExceptionType.badResponse => _fromStatus(error),
      DioExceptionType.unknown => const UnknownFailure(),
    };
  }

  static ApiException _fromStatus(DioException e) {
    final status = e.response?.statusCode ?? 0;
    // The server's own message is used only for 4xx, where it is written for
    // a person. A 5xx body is never shown: it can carry a stack trace, and it
    // is not the user's problem either way.
    final (code, serverMessage) =
        status < 500 ? _extract(e.response?.data) : (null, null);

    return switch (status) {
      401 => UnauthorisedFailure(code: code, serverMessage: serverMessage),
      403 => ForbiddenFailure(message: serverMessage, code: code),
      404 => NotFoundFailure(code: code),
      429 => RateLimitedFailure(
          message: serverMessage,
          retryAfter: _retryAfter(e.response),
        ),
      >= 400 && < 500 => ValidationFailure(
          serverMessage ?? 'That did not go through. Have another look.',
          code: code,
        ),
      _ => const ServerFailure(),
    };
  }

  /// Our backend answers every error as `{"error": {"code", "message"}}`.
  /// FastAPI's own request validation answers `{"detail": ...}`, where detail
  /// is a list of field errors: not for people, so it falls back to the
  /// generic line.
  static (String?, String?) _extract(Object? data) {
    if (data is! Map) return (null, null);
    final error = data['error'];
    if (error is Map) {
      final code = error['code'];
      return (code is String ? code : null, _bounded(error['message']));
    }
    return (null, _bounded(data['detail'] ?? data['message']));
  }

  /// Bounded so a hostile or broken server cannot push a wall of text into
  /// the UI.
  static String? _bounded(Object? text) =>
      text is String && text.isNotEmpty && text.length <= 200 ? text : null;

  static Duration? _retryAfter(Response<Object?>? response) {
    final seconds = int.tryParse(response?.headers.value('retry-after') ?? '');
    return seconds == null || seconds <= 0 ? null : Duration(seconds: seconds);
  }
}

final class OfflineFailure extends ApiException {
  const OfflineFailure()
      : super('You appear to be offline. Check your connection and try again.');
}

final class TimeoutFailure extends ApiException {
  const TimeoutFailure() : super('That took too long. Try again.');
}

final class UnauthorisedFailure extends ApiException {
  const UnauthorisedFailure({super.code, this.serverMessage})
      : super('Your session has ended. Sign in again.');

  /// What the server said, kept for the sign-in screen, where a 401 is not
  /// an ended session (see [WrongCodeFailure]).
  final String? serverMessage;
}

/// A refused sign-in code. The server answers it with a 401 like an ended
/// session, but it means something else, so the sign-in calls are sent
/// anonymously and turned into this, with the server's own words.
final class WrongCodeFailure extends ApiException {
  const WrongCodeFailure([String? message])
      : super(message ?? 'That code did not work. Check it, or ask for a new one.');
}

final class ForbiddenFailure extends ApiException {
  const ForbiddenFailure({String? message, super.code})
      : super(message ?? 'You do not have access to that.');
}

final class NotFoundFailure extends ApiException {
  const NotFoundFailure({super.code}) : super('That is no longer here.');
}

final class RateLimitedFailure extends ApiException {
  const RateLimitedFailure({String? message, this.retryAfter})
      : super(
          message ?? 'Too many tries. Wait a minute and try again.',
          code: 'rate_limited',
        );

  /// From the Retry-After header, when the server sent one.
  final Duration? retryAfter;
}

final class ValidationFailure extends ApiException {
  const ValidationFailure(super.message, {super.code});
}

final class ServerFailure extends ApiException {
  const ServerFailure()
      : super('Something broke on our side. It is not you — try again shortly.');
}

final class SecurityFailure extends ApiException {
  const SecurityFailure()
      : super('We could not verify the connection, so we stopped.');
}

final class CancelledFailure extends ApiException {
  const CancelledFailure() : super('Cancelled.');
}

final class UnknownFailure extends ApiException {
  const UnknownFailure({super.debugDetail}) : super('Something went wrong.');
}
