import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:chat_app/core/service/background_call_service.dart';

class TokenStorage {
  final FlutterSecureStorage _storage;

  TokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'auth_user_id';
  static const _userNameKey = 'auth_user_name';
  static const _userEmailKey = 'auth_user_email';

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
    await BackgroundCallService.stop();
  }

  Future<void> saveUserId(String userId) async {
    await _storage.write(key: _userIdKey, value: userId);
  }

  Future<String?> getUserId() async {
    return await _storage.read(key: _userIdKey);
  }

  Future<void> deleteUserId() async {
    await _storage.delete(key: _userIdKey);
  }

  Future<void> saveUserProfile({required String name, required String email}) async {
    await _storage.write(key: _userNameKey, value: name);
    await _storage.write(key: _userEmailKey, value: email);
  }

  Future<String?> getUserName() => _storage.read(key: _userNameKey);

  Future<String?> getUserEmail() => _storage.read(key: _userEmailKey);

  Future<void> deleteUserProfile() async {
    await _storage.delete(key: _userNameKey);
    await _storage.delete(key: _userEmailKey);
  }
}
