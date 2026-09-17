import 'package:chat_app/feature/message/domain/reposity/message_repo.dart';

class OpenDirectConversationUsecase {
  final MessageRepo messageRepo;

  OpenDirectConversationUsecase(this.messageRepo);

  Future<int> call({required String participantId}) {
    return messageRepo.openDirectConversation(participantId: participantId);
  }
}
