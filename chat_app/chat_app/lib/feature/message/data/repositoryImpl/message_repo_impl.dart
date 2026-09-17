import 'dart:io';

import 'package:chat_app/feature/message/data/datasource/message_datasource.dart';
import 'package:chat_app/feature/message/data/datasource/message_socket_datasource.dart';
import 'package:chat_app/feature/message/domain/entity/message_entity.dart';
import 'package:chat_app/feature/message/domain/reposity/message_repo.dart';

class MessageRepoImpl implements MessageRepo {
  final MessageDataSource messageDataSource;
  final MessageSocketDataSource messageSocketDataSource;

  MessageRepoImpl({
    required this.messageDataSource,
    required this.messageSocketDataSource,
  });

  @override
  Future<int> openDirectConversation({required String participantId}) {
    return messageDataSource.openDirectConversation(
      participantId: participantId,
    );
  }

  @override
  Future<List<MessageEntity>> getMessages({required int conversationId}) {
    return messageDataSource.getMessages(conversationId: conversationId);
  }

  @override
  Stream<MessageEntity> connectSocket({required int conversationId}) {
    return messageSocketDataSource.connect(conversationId: conversationId);
  }

  @override
  void disconnectSocket() => messageSocketDataSource.disconnect();

 @override
  Future<MessageEntity> sendMessage({
    required int conversationId,
    required String content,
    String messageType = 'text',
    File? imageFile,
  }) async {
    Map<String, dynamic>? metadata;

    if (imageFile != null) {
      final imageUrl = await messageDataSource.uploadImage(imageFile);
      metadata = {'imageUrl': imageUrl};
    }

    return messageDataSource.sendMessage(
      conversationId: conversationId,
      content: content,
      messageType: messageType,
      metadata: metadata, // <-- this line was missing
    );
  }
}
