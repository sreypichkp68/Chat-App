import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chat_app/core/service/token_storage.dart';
import 'package:chat_app/feature/message/data/datasource/message_socket_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pusher_reverb_flutter/pusher_reverb_flutter.dart';

void main() {
  test('opening and closing chat preserves the shared call connection', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var connections = 0;
    final chatSubscribed = Completer<void>();
    final chatUnsubscribed = Completer<void>();
    final sockets = <WebSocket>[];
    server.listen((request) async {
      if (request.uri.path == '/auth') {
        await request.drain<void>();
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'auth': 'test-signature'}));
        await request.response.close();
        return;
      }
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      connections++;
      socket.add(jsonEncode({
        'event': 'pusher:connection_established',
        'data': jsonEncode({'socket_id': '1.1', 'activity_timeout': 120}),
      }));
      socket.listen((raw) {
        final message = jsonDecode(raw as String) as Map<String, dynamic>;
        final data = message['data'] as Map<String, dynamic>?;
        if (data?['channel'] != 'private-conversation.7') return;
        if (message['event'] == 'pusher:subscribe') {
          socket.add(jsonEncode({
            'event': 'pusher_internal:subscription_succeeded',
            'channel': data!['channel'], 'data': '{}',
          }));
          if (!chatSubscribed.isCompleted) chatSubscribed.complete();
        }
        if (message['event'] == 'pusher:unsubscribe' && !chatUnsubscribed.isCompleted) {
          chatUnsubscribed.complete();
        }
      });
    });
    final client = ReverbClient.instance(
      host: '127.0.0.1', port: server.port, appKey: 'test',
      authEndpoint: 'http://127.0.0.1:${server.port}/auth',
      authorizer: (_, _) async => {},
    );
    addTearDown(() async {
      client.unsubscribeFromChannel('calls-test');
      client.unsubscribeFromChannel('private-conversation.7');
      await Future<void>.delayed(Duration.zero);
      ReverbClient.resetInstance();
      for (final socket in sockets) { await socket.close(); }
      await server.close(force: true);
    });
    final ready = client.onConnectionStateChange.firstWhere(
      (state) => state == ConnectionState.connected,
    );
    await client.connect();
    await ready;
    final calls = client.subscribeToChannel('calls-test');
    final source = MessageSocketDataSourceImpl(tokenStorage: TokenStorage());
    source.connect(conversationId: 7);
    await chatSubscribed.future.timeout(const Duration(seconds: 5));
    expect(connections, 1);
    source.disconnect();
    await chatUnsubscribed.future.timeout(const Duration(seconds: 5));
    expect(client.connectionState, ConnectionState.connected);
    expect(client.subscribeToChannel('calls-test'), same(calls));
  });
}
