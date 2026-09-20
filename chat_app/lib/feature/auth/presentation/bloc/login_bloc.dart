import 'package:chat_app/core/service/injection_container.dart';
import 'package:chat_app/core/service/token_storage.dart';
import 'package:chat_app/feature/auth/domain/usecase/login_usecase.dart';
import 'package:chat_app/feature/auth/presentation/bloc/login_event.dart';
import 'package:chat_app/feature/auth/presentation/bloc/login_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final LoginUsecase loginUsecase;

  LoginBloc({required this.loginUsecase}) : super(LoginInitial()) {
    on<LoginRequestEvent>((event, emit) async {
      emit(LoginLoading());
      try {
        final loginData = await loginUsecase(
          email: event.email,
          password: event.password,
        );
        if (loginData.token.isEmpty) {
          emit(LoginError('The server did not return a login token.'));
          return;
        }
        final storage = sl<TokenStorage>();
        await storage.saveToken(loginData.token);
        await storage.saveUserProfile(
          name: loginData.name.isNotEmpty ? loginData.name : loginData.email,
          email: loginData.email,
        );
        if (loginData.userId.isNotEmpty) {
          await storage.saveUserId(loginData.userId);
        }

        try {
          await registerCallBloc();
        } catch (e) {
          // Call feature failed to init — log it, but don't block login.
        }

        emit(LoginSuccess());
      } catch (error) {
        emit(LoginError(error.toString()));
      }
    });

    on<CheckAuthStatusEvent>((event, emit) async {
      emit(AuthChecking());
      try {
        final token = await sl<TokenStorage>().getToken();
        if (token != null && token.isNotEmpty) {
          try {
            await registerCallBloc();
          } catch (e,st) {
            // Same here — don't block auto-login on call feature failure.
            debugPrint('registerCallBloc failed: $e\n$st'); 
          }
          emit(Authenticated());
          return;
        }
        emit(Unauthenticated());
      } catch (_) {
        emit(Unauthenticated());
      }
    });
  }
}
