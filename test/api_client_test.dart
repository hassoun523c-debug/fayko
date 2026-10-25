import 'dart:convert';

import 'package:fayko/core/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('API client preserves the versioned path and bearer header', () async {
    http.Request? captured;
    final client = ApiClient(
      baseUrl: 'https://api.example.test/api/v1/',
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'posts': <Object>[]}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final payload = await client.get(
      '/posts',
      token: 'signed-test-token',
      queryParameters: {'limit': '20'},
    );

    expect(captured?.url.path, '/api/v1/posts');
    expect(captured?.url.queryParameters['limit'], '20');
    expect(captured?.headers['authorization'], 'Bearer signed-test-token');
    expect(payload['posts'], isA<List<dynamic>>());
    client.close();
  });

  test('API client maps server error payloads to ApiException', () async {
    final client = ApiClient(
      baseUrl: 'https://api.example.test/api/v1',
      client: MockClient((_) async {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 'invalid_credentials',
              'message': 'بيانات الدخول غير صحيحة.',
            },
          }),
          401,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await expectLater(
      client.post('/auth/login', body: {
        'identifier': 'user@example.com',
        'password': 'test-password',
      }),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 401)
            .having((error) => error.code, 'code', 'invalid_credentials')
            .having(
              (error) => error.message,
              'message',
              'بيانات الدخول غير صحيحة.',
            ),
      ),
    );
    client.close();
  });
}
