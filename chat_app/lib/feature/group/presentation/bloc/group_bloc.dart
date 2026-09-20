import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usercase/create_group_usecase.dart';
import 'group_event.dart';
import 'group_state.dart';

class GroupBloc extends Bloc<GroupEvent, GroupState> {
  final CreateGroupUsecase createGroupUseCase;

  GroupBloc(this.createGroupUseCase) : super(GroupInitial()) {
    on<CreateGroupSubmitted>((event, emit) async {
      emit(GroupLoading());
      try {
        final group = await createGroupUseCase(
          title: event.title,
          avatarUrl: event.avatarUrl,
          memberIds: event.memberIds,
        );
        emit(GroupSuccess(group));
      } catch (e) {
        emit(GroupFailure(e.toString()));
      }
    });
  }
}
