abstract class RegisterEvent {}

class RegisterRequestEvent extends RegisterEvent {
  final String name;
  final String email;
  final String password;
  final String conpass;
  RegisterRequestEvent({
    required this.name,
    required this.email,
    required this.password,
    required this.conpass,
  });
}
