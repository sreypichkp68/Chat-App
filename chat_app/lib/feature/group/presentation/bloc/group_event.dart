abstract class GroupEvent {}

class CreateGroupSubmitted extends GroupEvent {
  final String title;
  final String? avatarUrl;
  final List<int> memberIds;

  CreateGroupSubmitted({
    required this.title,
    this.avatarUrl,
    required this.memberIds,
  });
}

class CreateGroupRequested extends GroupEvent {
  final String name;
  final List<String> memberIds; // or List<int> depending on your ID type

  CreateGroupRequested({required this.name, required this.memberIds});
}
