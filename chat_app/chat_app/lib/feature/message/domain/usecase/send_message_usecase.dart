import 'dart:io';
import 'package:chat_app/feature/message/domain/entity/message_entity.dart';
import 'package:chat_app/feature/message/domain/reposity/message_repo.dart';

class SendMessageUsecase {
  final MessageRepo messageRepo;
  SendMessageUsecase(this.messageRepo);

  Future<MessageEntity> call({
    required int conversationId,
    required String content,
    String messageType = 'text',
    File? imageFile,
  }) {
    return messageRepo.sendMessage(
      conversationId: conversationId,
      content: content,
      messageType: messageType,
      imageFile: imageFile,
    );
  }
}
