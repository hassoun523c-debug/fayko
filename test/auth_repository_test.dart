import 'dart:convert';

import 'package:fayko/core/network/api_client.dart';
import 'package:fayko/core/storage/token_store.dart';
import 'package:fayko/features/auth/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _MemoryTokenStore implements TokenStore {
  String? value;

  @override
  Future<void> clearToken() async {
    value = null;
  }

  @override
  Future<String?> readToken() async => value;

  @override
  Future<void> writeToken(String token) async {
    value = token;
  }
}

const _userJson = <String, dynamic>{
  'id': 'bb27c8a6-8c1a-4686-9478-33a7a7b7c3e1',
  'username': 'hassoun',
  'email': 'hassoun@example.com',
  'displayName': 'حيدر',
  'bio': '',
  'avatarUrl': null,
};

void main() {
  test('registration stores the returned token securely', () async {
    final store = _MemoryTokenStore();
    final api = ApiClient(
      baseUrl: 'https://api.example.test/api/v1',
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/auth/register');
        return http.Response(
          jsonEncode({
            'accessToken': 'new-access-token',
            'tokenType': 'Bearer',
            'expiresInSeconds': 3600,
            'user': _userJson,
          }),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final repository = RemoteAuthRepository(
      apiClient: api,
      tokenStore: store,
    );

    final session = await repository.register(
      username: 'hassoun',
      email: 'hassoun@example.com',
      password: 'a-long-test-password',
      displayName: 'حيدر',
    );

    expect(session.accessToken, 'new-access-token');
    expect(session.user.username, 'hassoun');
    expect(store.value, 'new-access-token');
    api.close();
  });

  test('restore session fetches the account using the saved token', () async {
    final store = _MemoryTokenStore()..value = 'saved-access-token';
    final api = ApiClient(
      baseUrl: 'https://api.example.test/api/v1',
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/me');
        expect(
          request.headers['authorization'],
          'Bearer saved-access-token',
        );
        return http.Response(
          jsonEncode({'user': _userJson}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final repository = RemoteAuthRepository(
      apiClient: api,
      tokenStore: store,
    );

    final session = await repository.restoreSession();

    expect(session?.user.displayName, 'حيدر');
    expect(session?.accessToken, 'saved-access-token');
    expect(store.value, 'saved-access-token');
    api.close();
  });

  test('restore session clears an expired token on 401', () async {
    final store = _MemoryTokenStore()..value = 'expired-token';
    final api = ApiClient(
      baseUrl: 'https://api.example.test/api/v1',
      client: MockClient((_) async {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 'invalid_access_token',
              'message': 'انتهت صلاحية الجلسة.',
            },
          }),
          401,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final repository = RemoteAuthRepository(
      apiClient: api,
      tokenStore: store,
    );

    final session = await repository.restoreSession();

    expect(session, isNull);
    expect(store.value, isNull);
    api.close();
  });

  test('logout revokes the server session and clears the saved token', () async {
    final store = _MemoryTokenStore()..value = 'existing-access-token';
    final api = ApiClient(
      baseUrl: 'https://api.example.test/api/v1',
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/auth/logout');
        expect(
          request.headers['authorization'],
          'Bearer existing-access-token',
        );
        return http.Response('', 204);
      }),
    );
    final repository = RemoteAuthRepository(
      apiClient: api,
      tokenStore: store,
    );

    await repository.logout();

    expect(store.value, isNull);
    api.close();
  });

  test('offline logout still clears the local token', () async {
    final store = _MemoryTokenStore()..value = 'offline-access-token';
    final api = ApiClient(
      baseUrl: 'https://api.example.test/api/v1',
      client: MockClient((_) async {
        throw http.ClientException('offline');
      }),
    );
    final repository = RemoteAuthRepository(
      apiClient: api,
      tokenStore: store,
    );

    await repository.logout();

    expect(store.value, isNull);
    api.close();
  });
}
