/// HTTP methods supported by [ApiClient].
enum ApiHttpMethod { get, post, put, patch, delete }

/// Generic outbound HTTP request. Domain/feature DTOs are not represented here.
final class ApiRequest {
  const ApiRequest({
    required this.method,
    required this.path,
    this.headers = const {},
    this.queryParameters = const {},
    this.body,
    this.requestId,
  });

  final ApiHttpMethod method;
  final String path;
  final Map<String, String> headers;
  final Map<String, String> queryParameters;

  /// Raw request body. Prefer JSON-encodable maps/lists or a [String].
  final Object? body;

  /// Optional caller-supplied request ID. When null, the client generates one.
  final String? requestId;
}
