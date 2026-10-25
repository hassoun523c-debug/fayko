import '../../../core/network/api_client.dart';
import '../../../core/storage/token_store.dart';
import '../domain/auth_user.dart';

abstract interface class AuthRepository {
  Future<AuthSession?> restoreSession();

  Future<AuthSession> login({
    required String identifier,
    required String password,
  });

  Future<AuthSession> register({
    required String username,
    required String email,
    required String password,
    required String displayName,
  });

  Future<AuthUser> updateProfile({
    required String accessToken,
    required String displayName,
    required String bio,
  });

  Future<void> logout();
}

class RemoteAuthRepository implements AuthRepository {
  const RemoteAuthRepository({
    required ApiClient apiClient,
    required TokenStore tokenStore,
  })  : _apiClient = apiClient,
        _tokenStore = tokenStore;

  final ApiClient _apiClient;
  final TokenStore _tokenStore;

  @override
  Future<AuthSession?> restoreSession() async {
    final token = await _tokenStore.readToken();
    if (token == null || token.isEmpty) return null;

    try {
      final payload = await _apiClient.get('/auth/me', token: token);
      final userJson = payload['user'];
      if (userJson is! Map<String, dynamic>) {
        throw const FormatException('Missing current user in API response.');
      }
      return AuthSession(
        user: AuthUser.fromJson(userJson),
        accessToken: token,
      );
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _tokenStore.clearToken();
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) async {
    final payload = await _apiClient.post(
      '/auth/login',
      body: {
        'identifier': identifier.trim(),
        'password': password,
      },
    );
    return _saveSession(payload);
  }

  @override
  Future<AuthSession> register({
    required String username,
    required String email,
    required String password,
    required String displayName,
  }) async {
    final payload = await _apiClient.post(
      '/auth/register',
      body: {
        'username': username.trim(),
        'email': email.trim(),
        'password': password,
        'displayName': displayName.trim(),
      },
    );
    return _saveSession(payload);
  }

  Future<AuthSession> _saveSession(Map<String, dynamic> payload) async {
    final token = payload['accessToken'];
    final userJson = payload['user'];
    if (token is! String || token.isEmpty ||
        userJson is! Map<String, dynamic>) {
      throw const FormatException('Invalid authentication response.');
    }

    await _tokenStore.writeToken(token);
    return AuthSession(
      user: AuthUser.fromJson(userJson),
      accessToken: token,
    );
  }

  @override
  Future<AuthUser> updateProfile({
    required String accessToken,
    required String displayName,
    required String bio,
  }) async {
    final payload = await _apiClient.patch(
      '/auth/me',
      token: accessToken,
      body: {
        'displayName': displayName.trim(),
        'bio': bio.trim(),
      },
    );
    final userJson = payload['user'];
    if (userJson is! Map<String, dynamic>) {
      throw const FormatException('Invalid profile-update response.');
    }
    return AuthUser.fromJson(userJson);
  }

  @override
  Future<void> logout() => _tokenStore.clearToken();
}
