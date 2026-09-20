import 'package:chat_app/feature/group/data/datasource/group_remote_data_source.dart';

import '../../domain/entity/group_entity.dart';
import '../../domain/repository/group_repository.dart';

class GroupRepositoryImpl implements GroupRepository {
  final GroupRemoteDataSource remoteDataSource;

  GroupRepositoryImpl(this.remoteDataSource);

  @override
  Future<GroupEntity> createGroup({
    required String title,
    String? avatarUrl,
    required List<int> memberIds,
  }) async {
    return await remoteDataSource.createGroup(
      title: title,
      avatarUrl: avatarUrl,
      memberIds: memberIds,
    );
  }
}
