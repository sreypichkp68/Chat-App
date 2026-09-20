class ServerException implements Exception {
  final String message;
  ServerException({this.message="Sever Error"});
}

class CacheException implements Exception {
  
}