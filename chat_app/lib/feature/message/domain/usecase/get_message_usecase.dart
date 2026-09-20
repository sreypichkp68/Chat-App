// get_messages_usecase.dart
import 'package:chat_app/feature/message/domain/entity/message_entity.dart';
import 'package:chat_app/feature/message/domain/reposity/message_repo.dart';

class GetMessagesUsecase {
  final MessageRepo messageRepo;
  GetMessagesUsecase(this.messageRepo);

  Future<List<MessageEntity>> call({required int conversationId}) {
    return messageRepo.getMessages(conversationId: conversationId);
  }
}
