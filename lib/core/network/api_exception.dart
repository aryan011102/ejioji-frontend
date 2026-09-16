import 'package:dio/dio.dart';

/// One error type for the whole app.
///
/// Screens never see a [DioException]. They see this, and they show
/// [message] — which is written for a person and deliberately says nothing
/// about hosts, status codes or payloads. What actually went wrong is in
/// [debugDetail], which is logged in debug builds and dropped in release.
sealed class ApiException implements Exception {
  const ApiException(this.message, {this.debugDetail});

  final String message;
  final String? debugDetail;

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
    // The server's own message is used only for 4xx, where it is a validation
    // string meant for a person. A 5xx body is never shown — it can carry a
    // stack trace, and it is not the user's problem either way.
    final serverMessage = status < 500 ? _extractMessage(e.response?.data) : null;

    return switch (status) {
      401 => const UnauthorisedFailure(),
      403 => const ForbiddenFailure(),
      404 => const NotFoundFailure(),
      429 => const RateLimitedFailure(),
      >= 400 && < 500 => ValidationFailure(
          serverMessage ?? 'That did not go through. Have another look.',
        ),
      _ => const ServerFailure(),
    };
  }

  static String? _extractMessage(Object? data) {
    if (data is! Map) return null;
    final detail = data['detail'] ?? data['message'];
    // Bounded so a hostile or broken server cannot push a wall of text into
    // the UI.
    if (detail is String && detail.isNotEmpty && detail.length <= 200) {
      return detail;
    }
    return null;
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
  const UnauthorisedFailure() : super('Your session has ended. Sign in again.');
}

final class ForbiddenFailure extends ApiException {
  const ForbiddenFailure() : super('You do not have access to that.');
}

final class NotFoundFailure extends ApiException {
  const NotFoundFailure() : super('That is no longer here.');
}

final class RateLimitedFailure extends ApiException {
  const RateLimitedFailure()
      : super('Too many tries. Wait a minute and try again.');
}

final class ValidationFailure extends ApiException {
  const ValidationFailure(super.message);
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
