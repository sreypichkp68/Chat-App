import 'package:chat_app/feature/message/domain/entity/message_entity.dart';

abstract class MessageState {}

class MessageInitial extends MessageState {}

class MessageLoading extends MessageState {}

class MessageLoaded extends MessageState {
  final List<MessageEntity> messages;
  MessageLoaded(this.messages);
}

class MessageError extends MessageState {
  final String message;
  MessageError(this.message);
}
