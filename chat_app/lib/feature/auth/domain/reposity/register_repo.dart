import 'package:chat_app/feature/auth/domain/entity/register_entity.dart';

abstract class RegisterRepo {
  Future<RegisterEntity> register({
    required String name,
    required String email,
    required String password,
    required String conpass,
  });
}