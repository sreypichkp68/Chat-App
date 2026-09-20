import 'dart:convert';

import 'package:chat_app/core/constants/api_entpoint.dart';
import 'package:chat_app/core/service/token_storage.dart';
import 'package:chat_app/feature/profile/domain/entity/user_profile.dart';
import 'package:http/http.dart' as http;

class ProfileRemoteDataSource {
  final http.Client client;
  final TokenStorage storage;

  const ProfileRemoteDataSource({required this.client, required this.storage});

  Future<UserProfile> load() async {
    final name = await storage.getUserName();
    final email = await storage.getUserEmail();
    if ((name ?? '').isNotEmpty || (email ?? '').isNotEmpty) {
      return UserProfile(name: name ?? '', email: email ?? '');
    }

    final token = await storage.getToken();
    if (token == null || token.isEmpty) return UserProfile.empty;

    try {
      final response = await client.get(
        Uri.parse(ApiEntpoint.currentUser),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return UserProfile.empty;
      }

      final decoded = jsonDecode(response.body);
      final root = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
      final data = root['data'];
      final user = root['user'] is Map<String, dynamic>
          ? root['user'] as Map<String, dynamic>
          : data is Map<String, dynamic> && data['user'] is Map<String, dynamic>
          ? data['user'] as Map<String, dynamic>
          : data is Map<String, dynamic>
          ? data
          : root;
      final profile = UserProfile(
        name: user['name'] as String? ?? user['username'] as String? ?? '',
        email: user['email'] as String? ?? '',
      );
      await storage.saveUserProfile(name: profile.name, email: profile.email);
      if (user['id'] != null) await storage.saveUserId(user['id'].toString());
      return profile;
    } catch (_) {
      return UserProfile.empty;
    }
  }
}
