import 'dart:io';

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
