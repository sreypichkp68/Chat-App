import 'dart:convert';
import 'package:image_picker/image_picker.dart';

import 'package:chat_app/core/constants/api_entpoint.dart';
import 'package:chat_app/core/service/token_storage.dart';
import 'package:chat_app/feature/profile/domain/entity/user_profile.dart';
import 'package:http/http.dart' as http;

class ProfileRemoteDataSource {
  final http.Client client;
  final TokenStorage storage;

  const ProfileRemoteDataSource({required this.client, required this.storage});

  Future<UserProfile> load({bool requireFresh = false}) async {
    final name = await storage.getUserName();
    final email = await storage.getUserEmail();
    final cached = UserProfile(name: name ?? '', email: email ?? '');

    final token = await storage.getToken();
    if (token == null || token.isEmpty) {
      if (requireFresh) throw Exception('Please sign in again.');
      return cached;
    }

    try {
      final response = await client.get(
        Uri.parse(ApiEntpoint.currentUser),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Could not load profile. Please try again.');
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
      final profile = UserProfile.fromJson(user);
      await storage.saveUserProfile(name: profile.name, email: profile.email);
      if (user['id'] != null) await storage.saveUserId(user['id'].toString());
      return profile;
    } catch (_) {
      if (requireFresh) rethrow;
      return cached;
    }
  }

  Future<UserProfile> update({
    required String name,
    required String statusMessage,
    XFile? avatar,
  }) async {
    final token = await storage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Please sign in again.');
    }
    final request =
        http.MultipartRequest('POST', Uri.parse(ApiEntpoint.currentUser))
          ..headers.addAll({
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          })
          ..fields.addAll({
            '_method': 'PUT',
            'name': name.trim(),
            'status_message': statusMessage.trim(),
          });
    if (avatar != null) {
      final bytes = await avatar.readAsBytes();
      if (bytes.length > 5000 * 1024) {
        throw Exception('Choose a photo smaller than 5 MB.');
      }
      request.files.add(
        http.MultipartFile.fromBytes('avatar', bytes, filename: avatar.name),
      );
    }
    final response = await http.Response.fromStream(await client.send(request));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Could not save profile. Please try again.';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        message = body['message'] as String? ?? message;
      } catch (_) {}
      throw Exception(message);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final profile = UserProfile.fromJson(body['user'] as Map<String, dynamic>);
    await storage.saveUserProfile(name: profile.name, email: profile.email);
    return profile;
  }
}
