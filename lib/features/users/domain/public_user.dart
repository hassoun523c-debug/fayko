class PublicUser {
  const PublicUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.bio,
    required this.postsCount,
    required this.followersCount,
    required this.followingCount,
    required this.isFollowing,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final String displayName;
  final String bio;
  final int postsCount;
  final int followersCount;
  final int followingCount;
  final bool isFollowing;
  final String? avatarUrl;

  factory PublicUser.fromJson(Map<String, dynamic> json) {
    return PublicUser(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: (json['displayName'] as String?) ?? (json['username'] as String),
      bio: (json['bio'] as String?) ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      postsCount: (json['postsCount'] as num?)?.toInt() ?? 0,
      followersCount: (json['followersCount'] as num?)?.toInt() ?? 0,
      followingCount: (json['followingCount'] as num?)?.toInt() ?? 0,
      isFollowing: json['isFollowing'] as bool? ?? false,
    );
  }

  PublicUser copyWith({
    int? followersCount,
    bool? isFollowing,
  }) {
    return PublicUser(
      id: id,
      username: username,
      displayName: displayName,
      bio: bio,
      postsCount: postsCount,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount,
      isFollowing: isFollowing ?? this.isFollowing,
      avatarUrl: avatarUrl,
    );
  }
}
