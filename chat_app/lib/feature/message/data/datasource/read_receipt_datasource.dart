import 'dart:convert';

import 'package:chat_app/core/constants/api_entpoint.dart';
import 'package:chat_app/core/service/token_storage.dart';
import 'package:http/http.dart' as http;

class ReadReceiptDataSource {
  ReadReceiptDataSource({required this.client, required this.tokenStorage});

  final http.Client client;
  final TokenStorage tokenStorage;

  Uri _url(int conversationId) =>
      Uri.parse('${ApiEntpoint.conversations}/$conversationId/read-receipts');

  Future<Map<String, String>> _headers() async => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${await tokenStorage.getToken()}',
  };

  Future<Map<String, int>> getReceipts(int conversationId) async {
    final response = await client
        .get(_url(conversationId), headers: await _headers())
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Could not load read receipts');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return {
      for (final member in body['data'] as List)
        member['user_id'].toString():
            int.tryParse(member['last_read_message_id'].toString()) ?? 0,
    };
  }

  Future<void> markRead(int conversationId, int messageId) async {
    final response = await client
        .post(
          _url(conversationId),
          headers: await _headers(),
          body: jsonEncode({'message_id': messageId}),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Could not mark messages read');
    }
  }
}
