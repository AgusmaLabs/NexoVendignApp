import 'dart:convert';

import 'api_exception.dart';

/// Generic HTTP response returned by [ApiClient].
///
/// Feature layers are responsible for mapping bodies into DTOs/domain models.
final class ApiResponse {
  const ApiResponse({
    required this.statusCode,
    required this.body,
    required this.headers,
    required this.requestId,
  });

  final int statusCode;
  final String body;
  final Map<String, String> headers;
  final String requestId;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  /// Decodes [body] as JSON. Throws [SerializationException] on failure.
  Object? decodeJson() {
    if (body.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(body);
    } on FormatException catch (error) {
      throw SerializationException(
        'Failed to decode JSON response body',
        cause: error,
        requestId: requestId,
      );
    }
  }
}
