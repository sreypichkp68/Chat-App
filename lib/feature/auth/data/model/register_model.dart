import 'package:chat_app/feature/auth/domain/entity/register_entity.dart';

class RegisterModel extends RegisterEntity {
  RegisterModel({
    required super.id,
    required super.name,
    required super.email,
    required super.password,
    required super.conpass,
  });

  factory RegisterModel.fromJson(Map<String, dynamic> json) {
    final data = json['user'] as Map<String, dynamic>? ?? json;
    return RegisterModel(
      id: (data['id'] as num?)?.toInt() ?? 0,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      password: data['password'] as String? ?? '',
      conpass: data['conpass'] as String? ?? '',
    );
  }
}
