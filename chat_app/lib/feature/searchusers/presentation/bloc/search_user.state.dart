import 'package:chat_app/feature/searchusers/domain/entity/user_entity.dart';

abstract class SearchUsersState {
  const SearchUsersState();
}

class SearchUsersInitial extends SearchUsersState {
  const SearchUsersInitial();
}

class SearchUsersLoading extends SearchUsersState {
  const SearchUsersLoading();
}

class SearchUsersLoaded extends SearchUsersState {
  final List<UserEntity> results;
  const SearchUsersLoaded(this.results);
}

class SearchUsersError extends SearchUsersState {
  final String message;
  const SearchUsersError(this.message);
}
