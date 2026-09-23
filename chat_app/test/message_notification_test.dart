import 'dart:convert';

import 'package:chat_app/core/service/message_notification_listener.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'background inbox shows text and photos, filters duplicates and self',
    () async {
      var background = true;
      final shown = <String>[];
      final listener = MessageNotificationListener(
        userId: '2',
        isBackground: () => background,
        show: (id, title, body) async => shown.add('$id:$title:$body'),
      );
      Map<String, dynamic> message(
        int id, {
        String type = 'text',
        int sender = 1,
      }) => {
        'message': {
          'id': id,
          'conversation_id': 7,
          'sender_id': sender,
          'message_type': type,
          'content': 'Hello',
          'sender': {'name': 'Sok'},
        },
      };
      await listener.receive(jsonEncode(message(1)));
      await listener.receive(message(1));
      await listener.receive(message(2, type: 'image'));
      await listener.receive(message(7, type: 'audio'));
      await listener.receive(message(3, sender: 2));
      await listener.receive(message(4, type: 'call_log'));
      background = false;
      await listener.receive(message(5));
      background = true;
      await listener.receive(
        message(5),
      ); // No delayed duplicate after resuming.
      await listener.receive({'message': {}});
      expect(shown, [
        '7:Sok:Hello',
        '7:Sok:Sent you a photo',
        '7:Sok:Sent you a voice message',
      ]);
      await listener.dispose();
      await listener.receive(message(6));
      expect(shown, hasLength(3));
    },
  );
}
