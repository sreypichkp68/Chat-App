import 'dart:convert';
import 'package:chat_app/core/constants/api_entpoint.dart';
import 'package:chat_app/core/service/token_storage.dart';
import 'package:http/http.dart' as http;
import '../model/group_model.dart';

abstract class GroupRemoteDataSource {
  Future<GroupModel> createGroup({
    required String title,
    String? avatarUrl,
    required List<int> memberIds,
  });
}

class GroupRemoteDataSourceImpl implements GroupRemoteDataSource {
  final http.Client client;
  final TokenStorage tokenStorage;

  GroupRemoteDataSourceImpl({required this.client, required this.tokenStorage});

  @override
  Future<GroupModel> createGroup({
    required String title,
    String? avatarUrl,
    required List<int> memberIds,
  }) async {
    final authToken = await tokenStorage.getToken();
    if (authToken == null || authToken.isEmpty) {
      throw StateError('Sign in before creating a group.');
    }
    final response = await client.post(
      Uri.parse('${ApiEntpoint.url}/groups'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode({
        'title': title,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        'member_ids': memberIds,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return GroupModel.fromJson(data['conversation']);
    } else {
      throw Exception('Failed to create group: ${response.body}');
    }
  }
}
