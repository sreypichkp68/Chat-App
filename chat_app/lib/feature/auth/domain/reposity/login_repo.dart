import 'package:chat_app/feature/auth/domain/entity/login_entity.dart';

abstract class LoginRepo {
  Future<LoginEntity> login({
    required String email,
    required String password,
  });
}