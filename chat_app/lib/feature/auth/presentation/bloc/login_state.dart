abstract class LoginState {}

class LoginInitial extends LoginState {}

class LoginLoading extends LoginState {}
class AuthChecking extends LoginState {}

class Authenticated extends LoginState {}

class Unauthenticated extends LoginState {}

class LoginSuccess extends LoginState {}

class LoginError extends LoginState {
  final String message;
  LoginError(this.message);
}
