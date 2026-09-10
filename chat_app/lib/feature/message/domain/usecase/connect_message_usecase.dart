import 'package:chat_app/feature/message/domain/entity/message_entity.dart';
import 'package:chat_app/feature/message/domain/reposity/message_repo.dart';

class ConnectMessageUsecase {
  final MessageRepo messageRepo;
  ConnectMessageUsecase(this.messageRepo);

  Stream<MessageEntity> call({required int conversationId}) {
    return messageRepo.connectSocket(conversationId: conversationId);
  }
}
