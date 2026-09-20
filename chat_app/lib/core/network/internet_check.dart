import 'package:internet_connection_checker/internet_connection_checker.dart';

abstract class InternetCheck {
  Future<bool> get isConnected;
}
//Dependency  InternetConnectionChecker
class InternetCheckImpl implements InternetCheck {
  final InternetConnectionChecker internetConnectionChecker;
  InternetCheckImpl(this.internetConnectionChecker);

  @override
  Future<bool> get isConnected => throw internetConnectionChecker.hasConnection;
}
