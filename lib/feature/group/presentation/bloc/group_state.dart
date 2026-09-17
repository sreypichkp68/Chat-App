import '../../domain/entity/group_entity.dart';

abstract class GroupState {}

class GroupInitial extends GroupState {}

class GroupLoading extends GroupState {}

class GroupSuccess extends GroupState {
  final GroupEntity group;

  GroupSuccess(this.group);
}

class GroupFailure extends GroupState {
  final String error;

  GroupFailure(this.error);
}
