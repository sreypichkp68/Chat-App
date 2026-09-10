import 'package:chat_app/feature/auth/domain/entity/register_entity.dart';
import 'package:chat_app/feature/auth/domain/reposity/register_repo.dart';

class RegisterUsecase {
  final RegisterRepo registerRepo;
  RegisterUsecase(this.registerRepo);
  Future<RegisterEntity> call({
    required String name,
    required String email,
    required String password,
    required String conpass,
  }) {
    return registerRepo.register(
      name: name,
      email: email,
      password: password,
      conpass: conpass,
    );
  }
}
