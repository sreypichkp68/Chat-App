import 'package:chat_app/feature/auth/domain/entity/login_entity.dart';

class LoginModel extends LoginEntity {
  LoginModel({
    required super.userId,
    required super.name,
    required super.email,
    required super.token,
  });

  factory LoginModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final dataMap = data is Map<String, dynamic> ? data : <String, dynamic>{};
    final user = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : dataMap['user'] is Map<String, dynamic>
        ? dataMap['user'] as Map<String, dynamic>
        : dataMap.isNotEmpty
        ? dataMap
        : json;
    final token = json['token'] ?? json['access_token'] ?? dataMap['token'];

    return LoginModel(
      userId: user['id']?.toString() ?? '',
      name: user['name'] as String? ?? user['username'] as String? ?? '',
      email: user['email'] as String? ?? '',
      token: token is String ? token : '',
    );
  }
}
