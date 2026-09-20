import 'dart:async';
import 'package:chat_app/feature/message/domain/entity/message_entity.dart';
import 'package:chat_app/feature/message/domain/usecase/connect_message_usecase.dart';
import 'package:chat_app/feature/message/domain/usecase/get_message_usecase.dart';
import 'package:chat_app/feature/message/domain/usecase/send_message_usecase.dart';
import 'package:chat_app/feature/message/presentation/bloc/message_event.dart';
import 'package:chat_app/feature/message/presentation/bloc/message_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class _MessageReceived extends MessageEvent {
  final MessageEntity message;
  _MessageReceived(this.message);
}

class _MessagesRefreshRequested extends MessageEvent {
  final int conversationId;
  _MessagesRefreshRequested(this.conversationId);
}

class MessageBloc extends Bloc<MessageEvent, MessageState> {
  final GetMessagesUsecase getMessagesUsecase;
  final SendMessageUsecase sendMessageUsecase;
  final ConnectMessageUsecase connectSocketUsecase;

  StreamSubscription<MessageEntity>? _socketSub;
  Timer? _pollTimer;
  final List<MessageEntity> _messages = [];

  MessageBloc({
    required this.getMessagesUsecase,
    required this.sendMessageUsecase,
    required this.connectSocketUsecase,
  }) : super(MessageInitial()) {
    on<MessageLoadRequested>(_onLoadRequested);
    on<MessageSendRequested>(_onSendRequested);
    on<_MessageReceived>(_onMessageReceived);
    on<_MessagesRefreshRequested>(_onMessagesRefreshRequested);
  }
  Future<void> _onLoadRequested(
    MessageLoadRequested event,
    Emitter<MessageState> emit,
  ) async {
    emit(MessageLoading());
    try {
      final messages = await getMessagesUsecase.call(
        conversationId: event.conversationId,
      );
      _messages
        ..clear()
        ..addAll(messages)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      emit(MessageLoaded(List.of(_messages)));

      // Start listening for incoming messages in real time.
      _socketSub?.cancel();
      _socketSub = connectSocketUsecase
          .call(conversationId: event.conversationId)
          .listen((message) => add(_MessageReceived(message)));

      // Optional fallback polling, in case the socket drops.
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => add(_MessagesRefreshRequested(event.conversationId)),
      );
    } catch (e) {
      emit(MessageError(e.toString()));
    }
  }

  Future<void> _onSendRequested(
    MessageSendRequested event,
    Emitter<MessageState> emit,
  ) async {
    // 1. Optimistic local message so it appears instantly, before upload/send resolve.
    final optimisticId = -DateTime.now()
        .microsecondsSinceEpoch; // negative = temp id, avoids clashing with real server ids
    final optimisticMessage = MessageEntity(
      id: optimisticId,
      conversationId: event.conversationId,
      senderId:
          0, // TODO: replace with real current-user id from your session/auth source
      content: event.content,
      messageType: event.messageType,
      metadata: event.imageFile != null
          ? {'localPath': event.imageFile!.path}
          : null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _messages.add(optimisticMessage);
    emit(MessageLoaded(List.of(_messages)));

    try {
      final msg = await sendMessageUsecase.call(
        conversationId: event.conversationId,
        content: event.content,
        messageType: event.messageType,
        imageFile: event.imageFile,
      );

      // The socket or refresh may have added the server message before this
      // request finished. Keep one confirmed copy in either order.
      _messages.removeWhere((m) => m.id == optimisticId || m.id == msg.id);
      _messages.add(msg);
      _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      emit(MessageLoaded(List.of(_messages)));
    } catch (e) {
      print('DEBUG SEND ERROR: $e'); // new
      _messages.removeWhere((m) => m.id == optimisticId);
      emit(MessageLoaded(List.of(_messages)));
      emit(MessageError(e.toString()));
    }
  }

  void _onMessageReceived(_MessageReceived event, Emitter<MessageState> emit) {
    if (_messages.any((message) => message.id == event.message.id)) return;
    _messages.add(event.message);
    emit(MessageLoaded(List.of(_messages)));
  }

  Future<void> _onMessagesRefreshRequested(
    _MessagesRefreshRequested event,
    Emitter<MessageState> emit,
  ) async {
    try {
      final latest = await getMessagesUsecase.call(
        conversationId: event.conversationId,
      );
      final existingIds = _messages.map((message) => message.id).toSet();
      final newMessages = latest
          .where((message) => !existingIds.contains(message.id))
          .toList();
      if (newMessages.isEmpty) return;

      _messages.addAll(newMessages);
      _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      emit(MessageLoaded(List.of(_messages)));
    } catch (_) {
      // A temporary refresh failure should not hide messages already on screen.
    }
  }

  @override
  Future<void> close() {
    _socketSub?.cancel();
    _pollTimer?.cancel();
    return super.close();
  }
}
