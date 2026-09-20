import 'dart:async';
import 'dart:io';

import 'package:chat_app/feature/message/domain/entity/message_entity.dart';
import 'package:chat_app/feature/message/domain/reposity/message_repo.dart';
import 'package:chat_app/feature/message/domain/usecase/connect_message_usecase.dart';
import 'package:chat_app/feature/message/domain/usecase/get_message_usecase.dart';
import 'package:chat_app/feature/message/domain/usecase/send_message_usecase.dart';
import 'package:chat_app/feature/message/presentation/bloc/message_bloc.dart';
import 'package:chat_app/feature/message/presentation/bloc/message_event.dart';
import 'package:chat_app/feature/message/presentation/bloc/message_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _MessageRepo implements MessageRepo {
  final socket = StreamController<MessageEntity>.broadcast();
  final sendResult = Completer<MessageEntity>();

  @override
  Future<List<MessageEntity>> getMessages({
    required int conversationId,
  }) async => [];

  @override
  Future<MessageEntity> sendMessage({
    required int conversationId,
    required String content,
    String messageType = 'text',
    File? imageFile,
  }) => sendResult.future;

  @override
  Stream<MessageEntity> connectSocket({required int conversationId}) =>
      socket.stream;

  @override
  void disconnectSocket() {}

  @override
  Future<int> openDirectConversation({required String participantId}) async =>
      1;
}

void main() {
  test('socket delivery before send response leaves one message', () async {
    final repo = _MessageRepo();
    final bloc = MessageBloc(
      getMessagesUsecase: GetMessagesUsecase(repo),
      sendMessageUsecase: SendMessageUsecase(repo),
      connectSocketUsecase: ConnectMessageUsecase(repo),
    );
    addTearDown(() async {
      await bloc.close();
      await repo.socket.close();
    });

    bloc.add(MessageLoadRequested(conversationId: 1));
    await bloc.stream.firstWhere((state) => state is MessageLoaded);

    bloc.add(MessageSendRequested(conversationId: 1, content: 'Hello'));
    await bloc.stream.firstWhere(
      (state) => state is MessageLoaded && state.messages.any((m) => m.id < 0),
    );

    final saved = MessageEntity(
      id: 42,
      conversationId: 1,
      senderId: 1,
      content: 'Hello',
      messageType: 'text',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    repo.socket.add(saved);
    await bloc.stream.firstWhere(
      (state) =>
          state is MessageLoaded && state.messages.any((m) => m.id == 42),
    );

    repo.sendResult.complete(saved);
    final confirmed =
        await bloc.stream.firstWhere(
              (state) =>
                  state is MessageLoaded &&
                  state.messages.any((m) => m.id == 42) &&
                  state.messages.every((m) => m.id >= 0),
            )
            as MessageLoaded;
    expect(confirmed.messages.where((m) => m.id == 42), hasLength(1));
  });
}
