class UserProfile {
  final String name;
  final String email;

  const UserProfile({required this.name, required this.email});

  static const empty = UserProfile(name: '', email: '');
}
