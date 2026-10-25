class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.email,
    required this.displayName,
    required this.bio,
    this.avatarUrl,
    this.interests = const [],
  });

  final String id;
  final String username;
  final String email;
  final String displayName;
  final String bio;
  final String? avatarUrl;
  final List<String> interests;

  AuthUser copyWith({
    String? displayName,
    String? bio,
    String? avatarUrl,
    bool clearAvatar = false,
    List<String>? interests,
  }) {
    return AuthUser(
      id: id,
      username: username,
      email: email,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
      interests: interests ?? this.interests,
    );
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final rawInterests = json['interests'];
    return AuthUser(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      bio: (json['bio'] as String?) ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      interests: rawInterests is List
          ? rawInterests.whereType<String>().toList(growable: false)
          : const [],
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
  });

  final AuthUser user;
  final String accessToken;
}
