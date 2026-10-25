class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.email,
    required this.displayName,
    required this.bio,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final String email;
  final String displayName;
  final String bio;
  final String? avatarUrl;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      bio: (json['bio'] as String?) ?? '',
      avatarUrl: json['avatarUrl'] as String?,
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
