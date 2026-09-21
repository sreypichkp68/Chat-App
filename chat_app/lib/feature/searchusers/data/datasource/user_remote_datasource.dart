import 'dart:convert';
import 'package:chat_app/core/constants/api_entpoint.dart';
import 'package:chat_app/core/service/token_storage.dart';
import 'package:chat_app/feature/searchusers/data/model/user_model.dart';
import 'package:http/http.dart' as http;
import 'package:chat_app/feature/friends/data/datasource/friend_request_remote_datasource.dart';

abstract class UserRemoteDatasource {
  Future<List<UserModel>> searchUsers(String query);
}

class UserRemoteDatasourceImpl implements UserRemoteDatasource {
  final http.Client client;
  final TokenStorage tokenStorage;
  final FriendRequestRemoteDatasource friendsDatasource;

  UserRemoteDatasourceImpl({
    required this.client,
    required this.tokenStorage,
    required this.friendsDatasource,
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
    final data =
        body['users'] as List<dynamic>? ??
        body['data'] as List<dynamic>? ??
        const [];

    if (data.isEmpty) return [];
    final friendIds = (await friendsDatasource.getFriends())
        .map((friend) => friend.id)
        .toSet();
    return data.map((e) {
      final json = e as Map<String, dynamic>;
      return UserModel.fromJson(
        json,
        isFriend: friendIds.contains(json['id'].toString()),
      );
    }).toList();
  }
}
