import 'dart:convert';
import 'package:chat_app/core/constants/api_entpoint.dart';
import 'package:chat_app/core/service/token_storage.dart';
import 'package:chat_app/feature/searchusers/data/model/user_model.dart';
import 'package:http/http.dart' as http;

abstract class UserRemoteDatasource {
  Future<List<UserModel>> searchUsers(String query);
}

class UserRemoteDatasourceImpl implements UserRemoteDatasource {
  final http.Client client;
  final TokenStorage tokenStorage;

  UserRemoteDatasourceImpl({
    required this.client,
    required this.tokenStorage,
  });

  @override
  Future<List<UserModel>> searchUsers(String query) async {
    final uri = Uri.parse(
      ApiEntpoint.searchUsers,
    ).replace(queryParameters: {'q': query});

    final token = await tokenStorage.getToken();
    final response = await client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        // ⚠️ needs Authorization: Bearer <token> — see note below
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Search failed: ${response.statusCode} ${response.body}');
    }

    final Map<String, dynamic> body =
        jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['users'] as List<dynamic>? ??
        body['data'] as List<dynamic>? ??
        const [];

    return data
        .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
