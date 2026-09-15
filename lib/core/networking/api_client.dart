import 'dart:async' as async;
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../authentication/session_credential_provider.dart';
import '../authentication/session_exception.dart';
import '../config/app_config.dart';
import '../logging/app_logger.dart';
import 'api_exception.dart';
import 'api_request.dart';
import 'api_response.dart';
import 'request_id.dart';

/// Central HTTP abstraction for NexoVending public API communication.
abstract interface class ApiClient {
  Future<ApiResponse> send(ApiRequest request);

  Future<ApiResponse> get(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    String? requestId,
    bool authenticated = false,
  });

  Future<ApiResponse> post(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    Object? body,
    String? requestId,
    bool authenticated = false,
  });

  Future<ApiResponse> put(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    Object? body,
    String? requestId,
    bool authenticated = false,
  });

  Future<ApiResponse> patch(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    Object? body,
    String? requestId,
    bool authenticated = false,
  });

  Future<ApiResponse> delete(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    Object? body,
    String? requestId,
    bool authenticated = false,
  });
}

/// Default [ApiClient] backed by `package:http`.
final class HttpApiClient implements ApiClient {
  HttpApiClient({
    required this.config,
    required this.logger,
    required this.requestIdGenerator,
    this.credentialProvider,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client(),
       _ownsClient = httpClient == null;

  static const String requestIdHeader = 'X-Request-Id';
  static const String authorizationHeader = 'Authorization';

  final AppConfig config;
  final AppLogger logger;
  final RequestIdGenerator requestIdGenerator;
  final SessionCredentialProvider? credentialProvider;
  final http.Client _httpClient;
  final bool _ownsClient;

  void close() {
    if (_ownsClient) {
      _httpClient.close();
    }
  }

  @override
  Future<ApiResponse> get(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    String? requestId,
    bool authenticated = false,
  }) {
    return send(
      ApiRequest(
        method: ApiHttpMethod.get,
        path: path,
        headers: headers ?? const {},
        queryParameters: queryParameters ?? const {},
        requestId: requestId,
        authenticated: authenticated,
      ),
    );
  }

  @override
  Future<ApiResponse> post(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    Object? body,
    String? requestId,
    bool authenticated = false,
  }) {
    return send(
      ApiRequest(
        method: ApiHttpMethod.post,
        path: path,
        headers: headers ?? const {},
        queryParameters: queryParameters ?? const {},
        body: body,
        requestId: requestId,
        authenticated: authenticated,
      ),
    );
  }

  @override
  Future<ApiResponse> put(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    Object? body,
    String? requestId,
    bool authenticated = false,
  }) {
    return send(
      ApiRequest(
        method: ApiHttpMethod.put,
        path: path,
        headers: headers ?? const {},
        queryParameters: queryParameters ?? const {},
        body: body,
        requestId: requestId,
        authenticated: authenticated,
      ),
    );
  }

  @override
  Future<ApiResponse> patch(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    Object? body,
    String? requestId,
    bool authenticated = false,
  }) {
    return send(
      ApiRequest(
        method: ApiHttpMethod.patch,
        path: path,
        headers: headers ?? const {},
        queryParameters: queryParameters ?? const {},
        body: body,
        requestId: requestId,
        authenticated: authenticated,
      ),
    );
  }

  @override
  Future<ApiResponse> delete(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    Object? body,
    String? requestId,
    bool authenticated = false,
  }) {
    return send(
      ApiRequest(
        method: ApiHttpMethod.delete,
        path: path,
        headers: headers ?? const {},
        queryParameters: queryParameters ?? const {},
        body: body,
        requestId: requestId,
        authenticated: authenticated,
      ),
    );
  }

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    final requestId =
        (request.requestId != null && request.requestId!.trim().isNotEmpty)
        ? request.requestId!.trim()
        : requestIdGenerator.next();

    final uri = _resolveUri(request.path, request.queryParameters);
    final headers = <String, String>{
      ...request.headers,
      requestIdHeader: requestId,
    };

    if (request.authenticated) {
      final provider = credentialProvider;
      if (provider == null) {
        throw const SessionExpiredException(
          message:
              'Authenticated request requires a session credential provider.',
        );
      }
      final authorization = await provider.authorizationHeader();
      if (authorization == null || authorization.trim().isEmpty) {
        throw const SessionExpiredException();
      }
      // Do not overwrite an explicit Authorization already supplied by tests.
      headers.putIfAbsent(authorizationHeader, () => authorization);
    }

    final encodedBody = _encodeBody(request.body, headers, requestId);
    final stopwatch = Stopwatch()..start();

    logger.debug(
      'HTTP request',
      context: {
        'method': request.method.name.toUpperCase(),
        'endpoint': uri.path,
        'requestId': requestId,
      },
    );

    try {
      final response = await _dispatch(
        method: request.method,
        uri: uri,
        headers: headers,
        body: encodedBody,
      ).timeout(config.httpTimeout);

      stopwatch.stop();

      final apiResponse = ApiResponse(
        statusCode: response.statusCode,
        body: response.body,
        headers: response.headers,
        requestId: requestId,
      );

      logger.info(
        'HTTP response',
        context: {
          'method': request.method.name.toUpperCase(),
          'endpoint': uri.path,
          'status': response.statusCode,
          'requestId': requestId,
          'durationMs': stopwatch.elapsedMilliseconds,
        },
      );

      if (!apiResponse.isSuccess) {
        final exception = HttpException(
          'HTTP ${response.statusCode} for ${request.method.name.toUpperCase()} ${uri.path}',
          statusCode: response.statusCode,
          body: response.body,
          requestId: requestId,
        );
        logger.error(
          'HTTP error response',
          error: exception,
          context: {
            'method': request.method.name.toUpperCase(),
            'endpoint': uri.path,
            'status': response.statusCode,
            'requestId': requestId,
            'durationMs': stopwatch.elapsedMilliseconds,
          },
        );
        throw exception;
      }

      return apiResponse;
    } on HttpException {
      rethrow;
    } on async.TimeoutException catch (error, stackTrace) {
      stopwatch.stop();
      final exception = TimeoutException(
        'Request timed out after ${config.httpTimeout.inMilliseconds}ms',
        cause: error,
        requestId: requestId,
      );
      logger.error(
        'HTTP timeout',
        error: exception,
        stackTrace: stackTrace,
        context: {
          'method': request.method.name.toUpperCase(),
          'endpoint': uri.path,
          'requestId': requestId,
          'durationMs': stopwatch.elapsedMilliseconds,
        },
      );
      throw exception;
    } on SocketException catch (error, stackTrace) {
      stopwatch.stop();
      final exception = NetworkException(
        'Network failure while calling ${uri.path}',
        cause: error,
        requestId: requestId,
      );
      logger.error(
        'HTTP network failure',
        error: exception,
        stackTrace: stackTrace,
        context: {
          'method': request.method.name.toUpperCase(),
          'endpoint': uri.path,
          'requestId': requestId,
          'durationMs': stopwatch.elapsedMilliseconds,
        },
      );
      throw exception;
    } on http.ClientException catch (error, stackTrace) {
      stopwatch.stop();
      final exception = NetworkException(
        'Network failure while calling ${uri.path}',
        cause: error,
        requestId: requestId,
      );
      logger.error(
        'HTTP client failure',
        error: exception,
        stackTrace: stackTrace,
        context: {
          'method': request.method.name.toUpperCase(),
          'endpoint': uri.path,
          'requestId': requestId,
          'durationMs': stopwatch.elapsedMilliseconds,
        },
      );
      throw exception;
    } on SerializationException {
      rethrow;
    } on ApiException {
      rethrow;
    } catch (error, stackTrace) {
      stopwatch.stop();
      final exception = UnknownApiException(
        'Unexpected API client failure for ${uri.path}',
        cause: error,
        requestId: requestId,
      );
      logger.error(
        'HTTP unknown failure',
        error: exception,
        stackTrace: stackTrace,
        context: {
          'method': request.method.name.toUpperCase(),
          'endpoint': uri.path,
          'requestId': requestId,
          'durationMs': stopwatch.elapsedMilliseconds,
        },
      );
      throw exception;
    }
  }

  Uri _resolveUri(String path, Map<String, String> queryParameters) {
    final base = Uri.parse(config.apiBaseUrl);
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    final resolved = base.resolve(normalizedPath);
    if (queryParameters.isEmpty) {
      return resolved;
    }
    return resolved.replace(
      queryParameters: <String, String>{
        ...resolved.queryParameters,
        ...queryParameters,
      },
    );
  }

  String? _encodeBody(
    Object? body,
    Map<String, String> headers,
    String requestId,
  ) {
    if (body == null) {
      return null;
    }
    if (body is String) {
      return body;
    }
    try {
      headers.putIfAbsent('Content-Type', () => 'application/json');
      return jsonEncode(body);
    } on JsonUnsupportedObjectError catch (error) {
      throw SerializationException(
        'Failed to encode request body as JSON',
        cause: error,
        requestId: requestId,
      );
    }
  }

  Future<http.Response> _dispatch({
    required ApiHttpMethod method,
    required Uri uri,
    required Map<String, String> headers,
    required String? body,
  }) {
    return switch (method) {
      ApiHttpMethod.get => _httpClient.get(uri, headers: headers),
      ApiHttpMethod.post => _httpClient.post(uri, headers: headers, body: body),
      ApiHttpMethod.put => _httpClient.put(uri, headers: headers, body: body),
      ApiHttpMethod.patch => _httpClient.patch(
        uri,
        headers: headers,
        body: body,
      ),
      ApiHttpMethod.delete => _httpClient.delete(
        uri,
        headers: headers,
        body: body,
      ),
    };
  }
}
