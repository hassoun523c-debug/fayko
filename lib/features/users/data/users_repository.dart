import '../../../core/network/api_client.dart';
import '../domain/public_user.dart';

abstract interface class UsersRepository {
  Future<List<PublicUser>> searchUsers({
    required String accessToken,
    required String query,
  });

  Future<void> setFollowing({
    required String accessToken,
    required PublicUser user,
    required bool following,
  });
}

class RemoteUsersRepository implements UsersRepository {
  const RemoteUsersRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<PublicUser>> searchUsers({
    required String accessToken,
    required String query,
  }) async {
    final payload = await _apiClient.get(
      '/users/search',
      token: accessToken,
      queryParameters: {'q': query.trim(), 'limit': '20'},
    );
    final rawUsers = payload['users'];
    if (rawUsers is! List) {
      throw const FormatException('Invalid user-search response.');
    }
    return rawUsers
        .whereType<Map<String, dynamic>>()
        .map(PublicUser.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> setFollowing({
    required String accessToken,
    required PublicUser user,
    required bool following,
  }) async {
    final path = '/users/' + user.id + '/follow';
    if (following) {
      await _apiClient.post(path, token: accessToken);
    } else {
      await _apiClient.delete(path, token: accessToken);
    }
  }
}
