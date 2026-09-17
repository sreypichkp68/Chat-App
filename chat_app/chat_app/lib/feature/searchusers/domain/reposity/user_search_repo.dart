import 'package:chat_app/feature/searchusers/domain/entity/user_entity.dart';

abstract class UserSearchRepo {
  Future<List<UserEntity>> searchUsers(String query);
}
