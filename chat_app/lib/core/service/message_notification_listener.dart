import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:pusher_reverb_flutter/pusher_reverb_flutter.dart';

/// Session-owned inbox, independent of the currently open conversation.
class MessageNotificationListener {
  MessageNotificationListener({
    required this.userId,
    required this.show,
    required this.isBackground,
  });

  final String userId;
  final Future<void> Function(int conversationId, String title, String body)
  show;
  final bool Function() isBackground;
  final Set<String> _seen = {};
  StreamSubscription<dynamic>? _subscription;
  ReverbClient? _client;
  Future<void> _pending = Future.value();
  bool _disposed = false;

  void start(ReverbClient client) {
    _client = client;
    final channel = client.subscribeToPrivateChannel('private-inbox.$userId');
    _subscription = channel.stream.listen((event) {
      if (event.eventName != 'MessageSent') return;
      _pending = _pending.then((_) => receive(event.data)).catchError((
        Object e,
      ) {
        debugPrint('Message notification failed: $e');
      });
    });
  }

  Future<void> receive(dynamic data) async {
    if (_disposed) return;
    final decoded = data is String ? jsonDecode(data) : data;
    if (decoded is! Map || decoded['message'] is! Map) return;
    final message = decoded['message'] as Map;
    final id = message['id']?.toString();
    final conversationId = int.tryParse('${message['conversation_id']}');
    final type = message['message_type'];
    if (id == null ||
        conversationId == null ||
        '${message['sender_id']}' == userId ||
        (type != 'text' && type != 'image' && type != 'audio') ||
        !_seen.add(id)) {
      return;
    }
    if (_seen.length > 500) _seen.remove(_seen.first);
    if (!isBackground()) return;
    final sender = message['sender'];
    final name = sender is Map ? sender['name']?.toString().trim() : null;
    final content = message['content']?.toString().trim() ?? '';
    await show(
      conversationId,
      name == null || name.isEmpty ? 'New message' : name,
      type == 'image'
          ? 'Sent you a photo'
          : type == 'audio'
          ? 'Sent you a voice message'
          : content,
    );
  }

  Future<void> dispose() async {
    _disposed = true;
    await _subscription?.cancel();
    _client?.unsubscribeFromChannel('private-inbox.$userId');
    await _pending;
    _seen.clear();
  }
}
