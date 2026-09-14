import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/core/networking/api_client.dart';
import 'package:vendingapp/core/networking/api_exception.dart';
import 'package:vendingapp/core/networking/request_id.dart';

import '../../support/test_doubles.dart';

void main() {
  group('HttpApiClient integration', () {
    late HttpServer server;
    late Uri baseUri;
    late RecordingAppLogger logger;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      baseUri = Uri.parse('http://${server.address.host}:${server.port}');
      logger = RecordingAppLogger();

      server.listen((request) async {
        final requestId = request.headers.value('X-Request-Id');
        final body = await utf8.decoder.bind(request).join();

        if (request.uri.path == '/echo') {
          request.response.statusCode = 200;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'method': request.method,
              'path': request.uri.path,
              'requestId': requestId,
              'body': body,
              'custom': request.headers.value('x-test'),
            }),
          );
        } else if (request.uri.path == '/unauthorized') {
          request.response.statusCode = 401;
          request.response.write('{"error":"unauthorized"}');
        } else {
          request.response.statusCode = 404;
          request.response.write('missing');
        }
        await request.response.close();
      });
    });

    tearDown(() async {
      await server.close(force: true);
    });

    HttpApiClient buildClient() {
      return HttpApiClient(
        config: testConfig(apiBaseUrl: baseUri.toString()),
        logger: logger,
        requestIdGenerator: UuidRequestIdGenerator(),
      );
    }

    test('performs real HTTP POST against local server', () async {
      final client = buildClient();

      final response = await client.post(
        '/echo',
        headers: {'X-Test': 'abc'},
        body: <String, Object?>{'hello': 'world'},
        requestId: 'integration-request-id',
      );

      final json = response.decodeJson() as Map<String, Object?>;
      expect(response.statusCode, 200);
      expect(json['method'], 'POST');
      expect(json['path'], '/echo');
      expect(json['requestId'], 'integration-request-id');
      expect(json['custom'], 'abc');
      expect(jsonDecode(json['body']! as String), {'hello': 'world'});
    });

    test('maps real HTTP 401 to HttpException', () async {
      final client = buildClient();

      expect(
        () => client.get('/unauthorized'),
        throwsA(
          isA<HttpException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });
  });
}
