import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:chat_app/feature/searchusers/domain/usecase/search_user_usecase.dart';
import 'package:chat_app/feature/searchusers/presentation/bloc/search_user.state.dart';
import 'package:chat_app/feature/searchusers/presentation/bloc/search_user_event.dart';

class SearchUsersBloc extends Bloc<SearchUsersEvent, SearchUsersState> {
  final SearchUsersUsecase searchUsersUsecase;
  Timer? _debounce;

  SearchUsersBloc(this.searchUsersUsecase) : super(const SearchUsersInitial()) {
    on<SearchQueryChanged>(_onQueryChanged);
  }

  Future<void> _onQueryChanged(
    SearchQueryChanged event,
    Emitter<SearchUsersState> emit,
  ) async {
    _debounce?.cancel();

    if (event.query.trim().isEmpty) {
      emit(const SearchUsersInitial());
      return;
    }

    emit(const SearchUsersLoading());

    final completer = Completer<void>();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => completer.complete(),
    );
    await completer.future;

    try {
      final results = await searchUsersUsecase(event.query.trim());
      if (!isClosed) emit(SearchUsersLoaded(results));
    } catch (e) {
      if (!isClosed) emit(SearchUsersError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
