import 'package:chat_app/feature/searchusers/data/datasource/user_remote_datasource.dart';
import 'package:chat_app/feature/searchusers/domain/entity/user_entity.dart';
import 'package:chat_app/feature/searchusers/domain/reposity/user_search_repo.dart';

class UserRearchRepoImpl implements UserSearchRepo {
  final UserRemoteDatasource datasource;

  UserRearchRepoImpl(this.datasource);

  @override
  Future<List<UserEntity>> searchUsers(String query) {
    return datasource.searchUsers(query);
  }
}
