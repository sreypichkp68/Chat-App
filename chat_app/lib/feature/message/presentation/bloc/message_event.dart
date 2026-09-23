import 'dart:io';
import 'package:chat_app/feature/message/domain/entity/message_entity.dart';

/// A completed media upload, merged with any earlier socket delivery.
class MessageConfirmed extends MessageEvent {
  final MessageEntity message;
  MessageConfirmed(this.message);
}

abstract class MessageEvent {}

class MessageLoadRequested extends MessageEvent {
  final int conversationId;
  MessageLoadRequested({required this.conversationId});
}

class MessageSendRequested extends MessageEvent {
  final int conversationId;
  final String content;
  final String messageType;
  final File? imageFile;
  MessageSendRequested({
    required this.conversationId,
    required this.content,
    this.messageType = 'text',
    this.imageFile,
  });
}
