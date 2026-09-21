class UserProfile {
  final String name;
  final String email;

  final String? avatarUrl;
  final String? statusMessage;

  const UserProfile({
    required this.name,
    required this.email,
    this.avatarUrl,
    this.statusMessage,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final avatar = json['avatar_url'] as String?;
    return UserProfile(
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      avatarUrl: avatar,
      statusMessage: json['status_message'] as String?,
    );
  }

  static const empty = UserProfile(name: '', email: '');
}
