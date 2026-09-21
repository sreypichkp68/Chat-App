import 'package:chat_app/feature/searchusers/domain/entity/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.name,
    super.avatarUrl,
    super.statusMessage,
    super.isFriend,
  });

  factory UserModel.fromJson(
    Map<String, dynamic> json, {
    bool isFriend = false,
  }) {
    return UserModel(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      statusMessage: json['status_message'] as String?,
      isFriend: isFriend,
    );
  }
}
