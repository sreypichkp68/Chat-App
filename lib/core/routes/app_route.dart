import 'package:chat_app/feature/auth/presentation/screen/login_screen.dart';
import 'package:chat_app/feature/auth/presentation/screen/register_screen.dart';
import 'package:flutter/material.dart';

class AppRoute {
  static const String register = '/register';
  static const String login = '/login';

  static Route<dynamic> onGenerateRoute(RouteSettings setting) {
    switch (setting.name) {
      case register:
        return MaterialPageRoute(builder: (context) => RegisterScreen());
       case login:
        return MaterialPageRoute(builder: (context) => LoginScreen());
      default:
        return MaterialPageRoute(
          builder: (context) =>
              Scaffold(body: Center(child: Text("I Love you"))),
        );
    }
  }
}
