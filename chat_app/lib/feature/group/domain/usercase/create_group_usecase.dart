import '../entity/group_entity.dart';
import '../repository/group_repository.dart';

class CreateGroupUsecase {
  final GroupRepository repository;

  CreateGroupUsecase(this.repository);

  Future<GroupEntity> call({
    required String title,
    String? avatarUrl,
    required List<int> memberIds,
  }) {
    return repository.createGroup(
      title: title,
      avatarUrl: avatarUrl,
      memberIds: memberIds,
    );
  }
}
