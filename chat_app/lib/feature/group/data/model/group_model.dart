import '../../domain/entity/group_entity.dart';

class GroupModel extends GroupEntity {
  GroupModel({
    required super.id,
    required super.type,
    required super.title,
    super.avatarUrl,
    required super.createdBy,
    required super.members,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'],
      type: json['type'],
      title: json['title'],
      avatarUrl: json['avatar_url'],
      createdBy: json['created_by'],
      members: (json['users'] as List)
          .map((user) => GroupMemberModel.fromJson(user))
          .toList(),
    );
  }
}

class GroupMemberModel extends GroupMemberEntity {
  GroupMemberModel({
    required super.id,
    required super.name,
    super.avatarUrl,
    required super.role,
  });

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) {
    return GroupMemberModel(
      id: json['id'],
      name: json['name'],
      avatarUrl: json['avatar_url'],
      role: json['pivot']?['role'] ?? 'member',
    );
  }
}