import 'dart:async';

import 'package:chat_app/core/service/injection_container.dart';
import 'package:chat_app/core/service/token_storage.dart';
import 'package:chat_app/feature/call/presentation/bloc/call.bloc.dart';
import 'package:chat_app/feature/message/data/datasource/read_receipt_datasource.dart';
import 'package:chat_app/feature/message/domain/entity/message_entity.dart';
import 'package:chat_app/feature/message/domain/reposity/message_repo.dart';
import 'package:chat_app/feature/message/domain/usecase/connect_message_usecase.dart';
import 'package:chat_app/feature/message/domain/usecase/get_message_usecase.dart';
import 'package:chat_app/feature/message/domain/usecase/send_message_usecase.dart';
import 'package:chat_app/feature/message/presentation/bloc/message_bloc.dart';
import 'package:chat_app/feature/message/presentation/screen/conversation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Calls extends Fake implements CallBloc {}

class _Storage extends Fake implements TokenStorage {
  @override
  Future<String?> getUserId() async => '1';
}

class _Receipts extends Fake implements ReadReceiptDataSource {
  final marked = <int>[];
  @override
  Future<Map<String, int>> getReceipts(int conversationId) async => {};
  @override
  Future<void> markRead(int conversationId, int messageId) async {
    marked.add(messageId);
  }
}

MessageEntity _message(int id) => MessageEntity(
  id: id,
  conversationId: 1,
  senderId: 2,
  content: 'Message $id',
  messageType: 'text',
  createdAt: DateTime(2026, 1, 1, 0, id),
  updatedAt: DateTime(2026),
);

class _Repo extends Fake implements MessageRepo {
  final socket = StreamController<MessageEntity>.broadcast();
  final messages = List.generate(40, (index) => _message(index + 1));
  void receive(int id) {
    final message = _message(id);
    messages.add(message);
    socket.add(message);
  }

  @override
  Future<List<MessageEntity>> getMessages({
    required int conversationId,
  }) async => List.of(messages);
  @override
  Stream<MessageEntity> connectSocket({required int conversationId}) =>
      socket.stream;
}

void main() {
  testWidgets('only foreground, uncovered chat acknowledges visible messages', (
    tester,
  ) async {
    await sl.reset();
    final repo = _Repo();
    final receipts = _Receipts();
    sl.registerSingleton<TokenStorage>(_Storage());
    sl.registerSingleton<ReadReceiptDataSource>(receipts);
    sl.registerSingleton<CallBloc>(_Calls());
    sl.registerFactory(
      () => MessageBloc(
        getMessagesUsecase: GetMessagesUsecase(repo),
        sendMessageUsecase: SendMessageUsecase(repo),
        connectSocketUsecase: ConnectMessageUsecase(repo),
      ),
    );
    addTearDown(() async {
      await repo.socket.close();
      await sl.reset();
    });
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      const GetMaterialApp(
        home: ConversationScreen(
          conversationId: 1,
          participantId: '2',
          participantName: 'Sok',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(receipts.marked, contains(40));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    repo.receive(41);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(receipts.marked, isNot(contains(41)));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    expect(receipts.marked, contains(41));

    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Another screen')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    repo.receive(42);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(receipts.marked, isNot(contains(42)));

    navigator.pop();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    expect(receipts.marked, contains(42));

    final list = tester.widget<ListView>(find.byType(ListView));
    list.controller!.jumpTo(0);
    await tester.pumpAndSettle();
    repo.receive(43);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    expect(receipts.marked, isNot(contains(43)));
    list.controller!.jumpTo(list.controller!.position.maxScrollExtent);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    expect(receipts.marked, contains(43));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
