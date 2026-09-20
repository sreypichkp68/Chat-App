class GroupEntity {
  final int id;
  final String type;
  final String title;
  final String? avatarUrl;
  final int createdBy;
  final List<GroupMemberEntity> members;

  GroupEntity({
    required this.id,
    required this.type,
    required this.title,
    this.avatarUrl,
    required this.createdBy,
    required this.members,
  });
}

class GroupMemberEntity {
  final int id;
  final String name;
  final String? avatarUrl;
  final String role;

  GroupMemberEntity({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.role,
  });
}
