import '../entity/group_entity.dart';

abstract class GroupRepository {
  Future<GroupEntity> createGroup({
    required String title,
    String? avatarUrl,
    required List<int> memberIds,
  });
}