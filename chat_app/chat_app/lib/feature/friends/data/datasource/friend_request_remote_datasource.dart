import 'dart:convert';

import 'package:chat_app/core/constants/api_entpoint.dart';
import 'package:chat_app/core/service/token_storage.dart';
import 'package:http/http.dart' as http;

abstract class FriendRequestRemoteDatasource {
  Future<void> sendFriendRequest({required String receiverId});
  Future<List<IncomingFriendRequest>> getIncomingRequests();
  Future<void> updateRequest({required String requestId, required String status});
  Future<List<FriendContact>> getFriends();
  Future<void> deleteFriend({required String friendId});
}

class FriendContact {
  final String id;
  final String name;
  final String email;

  const FriendContact({
    required this.id,
    required this.name,
    required this.email,
  });

  factory FriendContact.fromJson(Map<String, dynamic> json) {
    return FriendContact(
      id: json['id'].toString(),
      name: json['name'] as String? ?? 'Unknown user',
      email: json['email'] as String? ?? '',
    );
  }
}

class IncomingFriendRequest {
  final String id;
  final String senderId;
  final String senderName;
  final String senderEmail;

  const IncomingFriendRequest({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderEmail,
  });

  factory IncomingFriendRequest.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'] as Map<String, dynamic>? ?? const {};
    return IncomingFriendRequest(
      id: json['id'].toString(),
      senderId: sender['id'].toString(),
      senderName: sender['name'] as String? ?? 'Unknown user',
      senderEmail: sender['email'] as String? ?? '',
    );
  }
}

class FriendRequestRemoteDatasourceImpl
    implements FriendRequestRemoteDatasource {
  final http.Client client;
  final TokenStorage tokenStorage;

  FriendRequestRemoteDatasourceImpl({
    required this.client,
    required this.tokenStorage,
  });

  @override
  Future<void> sendFriendRequest({required String receiverId}) async {
    final response = await client.post(
      Uri.parse(ApiEntpoint.friendRequests),
      headers: await _headers(json: true),
      body: jsonEncode({'receiver_id': receiverId}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response));
    }
  }

  @override
  Future<List<IncomingFriendRequest>> getIncomingRequests() async {
    final response = await client.get(
      Uri.parse(ApiEntpoint.friendRequests),
      headers: await _headers(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response));
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final requests = body['data'] as List<dynamic>? ?? const [];
    return requests
        .map((item) => IncomingFriendRequest.fromJson(
              item as Map<String, dynamic>,
            ))
        .toList();
  }

  @override
  Future<void> updateRequest({
    required String requestId,
    required String status,
  }) async {
    final response = await client.put(
      Uri.parse('${ApiEntpoint.friendRequests}/$requestId'),
      headers: await _headers(json: true),
      body: jsonEncode({'status': status}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response));
    }
  }

  @override
  Future<List<FriendContact>> getFriends() async {
    final response = await client.get(
      Uri.parse(ApiEntpoint.friends),
      headers: await _headers(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response));
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final friends = body['data'] as List<dynamic>? ?? const [];
    return friends
        .map((item) => FriendContact.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> deleteFriend({required String friendId}) async {
    final response = await client.delete(
      Uri.parse('${ApiEntpoint.friends}/$friendId'),
      headers: await _headers(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response));
    }
  }

  Future<Map<String, String>> _headers({bool json = false}) async {
    final token = await tokenStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Your session has expired. Please log in again.');
    }
    return {
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  String _errorMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['message'] as String? ?? 'Could not send friend request.';
    } catch (_) {
      return 'Could not send friend request (${response.statusCode}).';
    }
  }
}
