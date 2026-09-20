abstract class SearchUsersEvent {
  const SearchUsersEvent();
}

class SearchQueryChanged extends SearchUsersEvent {
  final String query;
  const SearchQueryChanged(this.query);
}
