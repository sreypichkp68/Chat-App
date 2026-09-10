import 'dart:convert';
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
  final String baseUrl;
  final String authToken;

  GroupRemoteDataSourceImpl({
    required this.client,
    required this.baseUrl,
    required this.authToken,
  });

  @override
  Future<GroupModel> createGroup({
    required String title,
    String? avatarUrl,
    required List<int> memberIds,
  }) async {
    final response = await client.post(
      Uri.parse('$baseUrl/api/groups'),
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
