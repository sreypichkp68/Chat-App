import 'dart:convert';
import 'package:chat_app/core/constants/api_entpoint.dart';
import 'package:chat_app/core/service/token_storage.dart';
import 'package:http/http.dart' as http;
import '../model/group_model.dart';

abstract class GroupRemoteDataSource {
  Future<void> removeMember({required int groupId, required int userId});
  Future<GroupModel> getGroup(int groupId);
  Future<GroupModel> addMembers({
    required int groupId,
    required List<int> memberIds,
  });
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

  Future<Map<String, String>> _headers() async {
    final authToken = await tokenStorage.getToken();
    if (authToken == null || authToken.isEmpty) {
      throw StateError('Sign in to manage a group.');
    }
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $authToken',
    };
  }

  @override
  Future<void> removeMember({required int groupId, required int userId}) async {
    final response = await client.delete(
      Uri.parse('${ApiEntpoint.url}/groups/$groupId/members/$userId'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Could not remove member: ${response.body}');
    }
  }

  @override
  Future<GroupModel> getGroup(int groupId) async {
    final response = await client.get(
      Uri.parse('${ApiEntpoint.url}/groups/$groupId'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Could not load group members: ${response.body}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return GroupModel.fromJson(data['conversation'] as Map<String, dynamic>);
  }

  @override
  Future<GroupModel> addMembers({
    required int groupId,
    required List<int> memberIds,
  }) async {
    final response = await client.post(
      Uri.parse('${ApiEntpoint.url}/groups/$groupId/members'),
      headers: await _headers(),
      body: jsonEncode({'member_ids': memberIds}),
    );
    if (response.statusCode != 200) {
      throw Exception('Could not add members: ${response.body}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return GroupModel.fromJson(data['conversation'] as Map<String, dynamic>);
  }

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
