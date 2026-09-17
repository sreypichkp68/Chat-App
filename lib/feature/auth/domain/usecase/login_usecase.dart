import 'package:chat_app/feature/auth/domain/entity/login_entity.dart';
import 'package:chat_app/feature/auth/domain/reposity/login_repo.dart';

class LoginUsecase {
  final LoginRepo loginRepo;
  LoginUsecase(this.loginRepo);
  Future<LoginEntity> call({
    required String email,
    required String password,
  }) async {
    return await loginRepo.login(
      email: email,
      password: password,
    );
  }
}
