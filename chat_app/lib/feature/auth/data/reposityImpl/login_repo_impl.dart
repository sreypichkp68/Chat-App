import 'package:chat_app/feature/auth/data/datasource/login_data_source.dart';
import 'package:chat_app/feature/auth/domain/entity/login_entity.dart';
import 'package:chat_app/feature/auth/domain/reposity/login_repo.dart';

class LoginRepoImpl implements LoginRepo {
  final LoginDataSource loginDataSource;
  LoginRepoImpl({required this.loginDataSource});

  @override
  Future<LoginEntity> login({
    required String email,
    required String password,
  }) async {
    final model = await loginDataSource.login(
      email: email,
      password: password,
    );
    return model;
  }
}
