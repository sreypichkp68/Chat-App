import 'package:chat_app/core/service/injection_container.dart';
import 'package:chat_app/core/service/notification_service.dart';
import 'package:chat_app/feature/auth/presentation/bloc/login_bloc.dart';
import 'package:chat_app/feature/auth/presentation/bloc/register_bloc.dart';
import 'package:chat_app/feature/auth/presentation/screen/auth_gate.dart';
import 'package:chat_app/feature/group/presentation/bloc/group_bloc.dart';
import 'package:chat_app/feature/searchusers/presentation/bloc/search_user_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  initDependencies();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => sl<LoginBloc>()),
        BlocProvider(create: (context) => sl<RegisterBloc>()),
        BlocProvider(create: (context) => sl<SearchUsersBloc>()),
        BlocProvider(create: (context) => sl<GroupBloc>()),
        // CallBloc is intentionally NOT provided here — it doesn't exist
        // until after login. See AuthGate's _AuthenticatedShell.
      ],
      child: GetMaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        ),
        home: const AuthGate(),
      ),
    );
  }
}
