import 'package:chat_app/feature/message/data/datasource/message_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

ConversationSummary summary({int? readId, int senderId = 2, bool empty = false}) =>
    ConversationSummary.fromJson({
      'id': 1,
      'type': 'direct',
      'members': [
        {'user_id': 1, 'last_read_message_id': readId, 'user': {'id': 1, 'name': 'Me'}},
        {'user_id': 2, 'user': {'id': 2, 'name': 'Sok'}},
      ],
      'last_message': empty ? null : {
        'id': 10, 'sender_id': senderId, 'content': 'Hello', 'message_type': 'text',
      },
    }, currentUserId: '1');

void main() {
  test('incoming preview is unread until acknowledged', () {
    expect(summary().isUnread, isTrue);
    expect(summary(readId: 9).isUnread, isTrue);
    expect(summary(readId: 10).isUnread, isFalse);
    expect(summary(readId: 11).isUnread, isFalse);
  });

  test('outgoing messages and empty chats are not unread', () {
    expect(summary(senderId: 1).isUnread, isFalse);
    expect(summary(empty: true).isUnread, isFalse);
  });
}
