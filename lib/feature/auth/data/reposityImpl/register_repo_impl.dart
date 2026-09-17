import 'package:chat_app/feature/auth/data/datasource/register_data_source.dart';
import 'package:chat_app/feature/auth/domain/entity/register_entity.dart';
import 'package:chat_app/feature/auth/domain/reposity/register_repo.dart';

class RegisterRepoImpl implements RegisterRepo {
  final RegisterDataSource registerDataSource;
  RegisterRepoImpl({required this.registerDataSource});
  @override
  Future<RegisterEntity> register({
    required String name,
    required String email,
    required String password,
    required String conpass,
  }) async {
    final model = await registerDataSource.register(
      name: name,
      email:email,
      password: password,
      conpass: conpass,
    );
    return model;
  }
}
