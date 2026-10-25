import '../../../core/network/api_client.dart';
import '../domain/feed_post.dart';

abstract interface class FeedRepository {
  Future<List<FeedPost>> loadFeed({required String accessToken});

  Future<FeedPost> createPost({
    required String accessToken,
    required String body,
    String category = 'general',
  });

  Future<void> setLiked({
    required String accessToken,
    required FeedPost post,
    required bool liked,
  });

  Future<List<FeedComment>> loadComments({
    required String accessToken,
    required String postId,
  });

  Future<FeedComment> createComment({
    required String accessToken,
    required String postId,
    required String body,
  });
}

class RemoteFeedRepository implements FeedRepository {
  const RemoteFeedRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<FeedPost>> loadFeed({required String accessToken}) async {
    final payload = await _apiClient.get(
      '/posts',
      token: accessToken,
      queryParameters: {'limit': '20'},
    );
    final rawPosts = payload['posts'];
    if (rawPosts is! List) {
      throw const FormatException('Invalid feed response.');
    }
    return rawPosts
        .whereType<Map<String, dynamic>>()
        .map(FeedPost.fromJson)
        .toList(growable: false);
  }

  @override
  Future<FeedPost> createPost({
    required String accessToken,
    required String body,
    String category = 'general',
  }) async {
    final payload = await _apiClient.post(
      '/posts',
      token: accessToken,
      body: {'body': body, 'category': category},
    );
    final rawPost = payload['post'];
    if (rawPost is! Map<String, dynamic>) {
      throw const FormatException('Invalid create-post response.');
    }
    return FeedPost.fromJson(rawPost);
  }

  @override
  Future<void> setLiked({
    required String accessToken,
    required FeedPost post,
    required bool liked,
  }) async {
    if (liked) {
      await _apiClient.post('/posts/${post.id}/like', token: accessToken);
    } else {
      await _apiClient.delete(
        '/posts/${post.id}/like',
        token: accessToken,
      );
    }
  }

  @override
  Future<List<FeedComment>> loadComments({
    required String accessToken,
    required String postId,
  }) async {
    final payload = await _apiClient.get(
      '/posts/$postId/comments',
      token: accessToken,
    );
    final rawComments = payload['comments'];
    if (rawComments is! List) {
      throw const FormatException('Invalid comments response.');
    }
    return rawComments
        .whereType<Map<String, dynamic>>()
        .map(FeedComment.fromJson)
        .toList(growable: false);
  }

  @override
  Future<FeedComment> createComment({
    required String accessToken,
    required String postId,
    required String body,
  }) async {
    final payload = await _apiClient.post(
      '/posts/$postId/comments',
      token: accessToken,
      body: {'body': body},
    );
    final rawComment = payload['comment'];
    if (rawComment is! Map<String, dynamic>) {
      throw const FormatException('Invalid create-comment response.');
    }
    return FeedComment.fromJson(rawComment);
  }
}
