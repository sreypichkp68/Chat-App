abstract class LoginEvent {}

class LoginRequestEvent extends LoginEvent {
  final String email;
  final String password;

  LoginRequestEvent({
    required this.email,
    required this.password,
  });
}
class CheckAuthStatusEvent extends LoginEvent {}
