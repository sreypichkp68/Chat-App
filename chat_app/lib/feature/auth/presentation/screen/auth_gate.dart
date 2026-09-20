import 'package:chat_app/core/service/injection_container.dart';
import 'package:chat_app/feature/auth/presentation/bloc/login_bloc.dart';
import 'package:chat_app/feature/auth/presentation/bloc/login_event.dart';
import 'package:chat_app/feature/auth/presentation/bloc/login_state.dart';
import 'package:chat_app/feature/auth/presentation/screen/login_screen.dart';
import 'package:chat_app/feature/call/goblecall/global_call_listener.dart';
import 'package:chat_app/feature/call/presentation/bloc/call.bloc.dart';
import 'package:chat_app/main_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    context.read<LoginBloc>().add(CheckAuthStatusEvent());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoginBloc, LoginState>(
      builder: (context, state) {
        if (state is Authenticated) {
          if (!sl.isRegistered<CallBloc>() || !sl.isReadySync<CallBloc>()) {
            return const MainScreen(); // degrade gracefully, no call feature this session
          }
          return BlocProvider.value(
            value: sl<CallBloc>(),
            child: GlobalCallListener(child: const MainScreen()),
          );
        }
        if (state is AuthChecking || state is LoginInitial) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return const LoginScreen();
      },
    );
  }
}
