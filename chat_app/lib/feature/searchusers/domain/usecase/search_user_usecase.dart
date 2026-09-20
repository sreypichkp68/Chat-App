import 'package:chat_app/feature/searchusers/domain/entity/user_entity.dart';
import 'package:chat_app/feature/searchusers/domain/reposity/user_search_repo.dart';

class SearchUsersUsecase {
  final UserSearchRepo repository;

  SearchUsersUsecase(this.repository);

  Future<List<UserEntity>> call(String query) {
    return repository.searchUsers(query);
  }
}
