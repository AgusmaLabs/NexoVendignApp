import '../errors/app_exception.dart';

/// Infrastructure exceptions produced by the networking layer.
///
/// Features must depend on these types, not on package-specific HTTP errors.
sealed class ApiException extends AppException {
  const ApiException(super.message, {super.cause, this.requestId});

  final String? requestId;
}

/// Connectivity / transport failure before an HTTP response is received.
final class NetworkException extends ApiException {
  const NetworkException(super.message, {super.cause, super.requestId});
}

/// Request exceeded the configured timeout.
final class TimeoutException extends ApiException {
  const TimeoutException(super.message, {super.cause, super.requestId});
}

/// Non-success HTTP response from the remote server.
final class HttpException extends ApiException {
  const HttpException(
    super.message, {
    required this.statusCode,
    this.body,
    super.cause,
    super.requestId,
  });

  final int statusCode;
  final String? body;
}

/// Response body could not be decoded as expected.
final class SerializationException extends ApiException {
  const SerializationException(super.message, {super.cause, super.requestId});
}

/// Unexpected failure inside the API client.
final class UnknownApiException extends ApiException {
  const UnknownApiException(super.message, {super.cause, super.requestId});
}
