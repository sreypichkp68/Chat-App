import 'package:chat_app/feature/auth/domain/usecase/register_usecase.dart';
import 'package:chat_app/feature/auth/presentation/bloc/register_event.dart';
import 'package:chat_app/feature/auth/presentation/bloc/register_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  final RegisterUsecase registerUsecase;
  RegisterBloc({required this.registerUsecase}) : super(RegisterInitial()) {
    on<RegisterRequestEvent>(onRegister);
  }
  void onRegister(RegisterRequestEvent event, Emitter emit) async {
    emit(RegisterLoading());
    try {
      await registerUsecase(
        name: event.name,
        email: event.email,
        password: event.password,
        conpass: event.conpass,
      );
      emit(RegisterSuccess());
    } catch (e) {
      emit(RegisterError(message: "Excepiton : $e"));
    }
  }
}
