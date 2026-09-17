import 'dart:io';
import 'package:chat_app/feature/message/domain/entity/message_entity.dart';

abstract class MessageRepo {
  Future<int> openDirectConversation({required String participantId});
  Future<List<MessageEntity>> getMessages({required int conversationId});
  Future<MessageEntity> sendMessage({
    required int conversationId,
    required String content,
    String messageType = 'text',
    File? imageFile,
  });
  Stream<MessageEntity> connectSocket({required int conversationId});
  void disconnectSocket();
}
