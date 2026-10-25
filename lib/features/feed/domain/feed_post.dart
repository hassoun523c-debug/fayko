class PostAuthor {
  const PostAuthor({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;

  factory PostAuthor.fromJson(Map<String, dynamic> json) {
    return PostAuthor(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: (json['displayName'] as String?) ?? (json['username'] as String),
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

class FeedPost {
  const FeedPost({
    required this.id,
    required this.body,
    required this.author,
    required this.likesCount,
    required this.commentsCount,
    required this.likedByMe,
    required this.createdAt,
  });

  final String id;
  final String body;
  final PostAuthor author;
  final int likesCount;
  final int commentsCount;
  final bool likedByMe;
  final DateTime createdAt;

  factory FeedPost.fromJson(Map<String, dynamic> json) {
    return FeedPost(
      id: json['id'] as String,
      body: json['body'] as String,
      author: PostAuthor.fromJson(
        json['author'] as Map<String, dynamic>,
      ),
      likesCount: (json['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (json['commentsCount'] as num?)?.toInt() ?? 0,
      likedByMe: json['likedByMe'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  FeedPost copyWith({
    int? likesCount,
    int? commentsCount,
    bool? likedByMe,
  }) {
    return FeedPost(
      id: id,
      body: body,
      author: author,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      likedByMe: likedByMe ?? this.likedByMe,
      createdAt: createdAt,
    );
  }
}

class FeedComment {
  const FeedComment({
    required this.id,
    required this.body,
    required this.author,
    required this.createdAt,
  });

  final String id;
  final String body;
  final PostAuthor author;
  final DateTime createdAt;

  factory FeedComment.fromJson(Map<String, dynamic> json) {
    return FeedComment(
      id: json['id'] as String,
      body: json['body'] as String,
      author: PostAuthor.fromJson(
        json['author'] as Map<String, dynamic>,
      ),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
