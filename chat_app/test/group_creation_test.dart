import 'dart:convert';

import 'package:chat_app/core/service/token_storage.dart';
import 'package:chat_app/feature/group/data/datasource/group_remote_data_source.dart';
import 'package:chat_app/feature/message/data/datasource/message_datasource.dart';
import 'package:chat_app/feature/message/data/model/message_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _TokenStorage extends TokenStorage {
  @override
  Future<String?> getToken() async => 'test-token';
}

void main() {
  test('group message retains sender name from the API', () {
    final message = MessageModel.fromJson({
      'id': 7,
      'conversation_id': 12,
      'sender_id': 2,
      'sender': {'id': 2, 'name': 'Sok'},
      'content': 'Hello',
      'message_type': 'text',
      'created_at': '2026-09-16T10:00:00Z',
      'updated_at': '2026-09-16T10:00:00Z',
    });

    expect(message.senderName, 'Sok');
  });

  test('group conversation uses its title in the chat list', () {
    final conversation = ConversationSummary.fromJson({
      'id': 12,
      'type': 'group',
      'title': 'Friends',
      'members': [],
    }, currentUserId: '1');

    expect(conversation.isGroup, isTrue);
    expect(conversation.participantName, 'Friends');
    expect(conversation.participantId, '12');
  });

  test('creates a group with selected user IDs and bearer token', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/groups');
      expect(request.headers['Authorization'], 'Bearer test-token');
      expect(jsonDecode(request.body), {
        'title': 'Friends',
        'member_ids': [2, 3],
      });
      return http.Response(
        jsonEncode({
          'conversation': {
            'id': 12,
            'type': 'group',
            'title': 'Friends',
            'avatar_url': null,
            'created_by': 1,
            'users': [
              {
                'id': 1,
                'name': 'Me',
                'avatar_url': null,
                'pivot': {'role': 'admin'},
              },
              {
                'id': 2,
                'name': 'Sok',
                'avatar_url': null,
                'pivot': {'role': 'member'},
              },
            ],
          },
        }),
        201,
      );
    });
    addTearDown(client.close);

    final group = await GroupRemoteDataSourceImpl(
      client: client,
      tokenStorage: _TokenStorage(),
    ).createGroup(title: 'Friends', memberIds: [2, 3]);

    expect(group.id, 12);
    expect(group.title, 'Friends');
    expect(group.members.map((member) => member.name), ['Me', 'Sok']);
  });
}
