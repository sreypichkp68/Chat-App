import 'package:chat_app/feature/message/domain/entity/message_entity.dart';
import 'package:chat_app/feature/message/presentation/widget/read_receipt_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MessageEntity message(
  int id, {
  int sender = 1,
  String type = 'text',
  bool unsent = false,
}) => MessageEntity(
  id: id,
  conversationId: 1,
  senderId: sender,
  content: 'Hello',
  messageType: type,
  metadata: unsent ? {'is_unsent': true} : null,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  test('no receipt for unseen messages or optimistic sends', () {
    expect(latestSeenMessageId([message(1)], '2', 0), isNull);
    expect(latestSeenMessageId([message(-1)], '2', 100), isNull);
  });

  test(
    'avatar follows latest read outgoing text or photo, not unread messages',
    () {
      final messages = [
        message(1),
        message(2, type: 'image'),
        message(3),
        message(4, sender: 2),
      ];
      expect(latestSeenMessageId(messages, '2', 1), 1);
      expect(latestSeenMessageId(messages, '2', 2), 2);
      expect(latestSeenMessageId(messages, '2', 4), 3);
    },
  );

  test('call logs and unsent messages do not get an avatar', () {
    expect(
      latestSeenMessageId(
        [message(1), message(2, unsent: true), message(3, type: 'call_log')],
        '2',
        3,
      ),
      1,
    );
  });

  testWidgets(
    'receipt has a small avatar, accessible label and initials fallback',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ReadReceiptAvatar(name: 'Sok')),
        ),
      );
      expect(find.text('S'), findsOneWidget);
      expect(find.bySemanticsLabel('Seen by Sok'), findsOneWidget);
      expect(tester.widget<CircleAvatar>(find.byType(CircleAvatar)).radius, 9);
    },
  );
}
