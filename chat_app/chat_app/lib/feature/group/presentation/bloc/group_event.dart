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
