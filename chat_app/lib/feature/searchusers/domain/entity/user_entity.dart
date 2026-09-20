class UserEntity {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? statusMessage;

  const UserEntity({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.statusMessage,
  });
}
