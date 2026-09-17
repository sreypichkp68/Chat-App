import 'dart:async';
import 'dart:convert';
import 'package:chat_app/core/constants/api_entpoint.dart';
import 'package:chat_app/core/service/token_storage.dart';
import 'package:chat_app/feature/message/data/model/message_model.dart';
import 'package:pusher_reverb_flutter/pusher_reverb_flutter.dart';

abstract class MessageSocketDataSource {
  Stream<MessageModel> connect({required int conversationId});
  void disconnect();
}

class MessageSocketDataSourceImpl implements MessageSocketDataSource {
  final TokenStorage tokenStorage;

  MessageSocketDataSourceImpl({required this.tokenStorage});

  ReverbClient? _client;
  StreamController<MessageModel>? _controller;
  String? _channelName;
  StreamSubscription? _events;

  @override
  Stream<MessageModel> connect({required int conversationId}) {
    disconnect();
    _controller = StreamController<MessageModel>.broadcast();
    _channelName = 'private-conversation.$conversationId';

    _initClient();

    return _controller!.stream;
  }

  Future<void> _initClient() async {
    try {
      final controller = _controller;
      final channelName = _channelName;
      if (controller == null || channelName == null) return;
      final client = ReverbClient.instance(
        host: ApiEntpoint.reverbHost,
        port: ApiEntpoint.reverbPort,
        appKey: ApiEntpoint.reverbKey,
        pingInterval: const Duration(seconds: 15),
        authEndpoint: ApiEntpoint.broadcastingAuth,
        useTLS:
            true, // FIX: Railway's port 443 is TLS-only; this was defaulting
        // to false (ws://), causing "Connection closed before full header was received".
        authorizer: (channelName, socketId) async {
          final token = await tokenStorage.getToken();
          return {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
          };
        },
      );

      _client = client;
      // Calls and messages share Reverb's singleton. Reconnecting it here
      // replaces the call socket and temporarily removes its subscriptions.
      if (client.connectionState != ConnectionState.connected) {
        final connected = client.onConnectionStateChange
            .firstWhere((state) => state == ConnectionState.connected)
            .timeout(const Duration(seconds: 20));
        if (client.connectionState == ConnectionState.disconnected ||
            client.connectionState == ConnectionState.error) {
          await client.connect();
        }
        await connected;
      }
      if (_controller != controller || controller.isClosed) return;

      // FIX: was subscribeToChannel(_channelName!), the PUBLIC-channel method.
      // Public channels never call the authorizer, so this subscription was
      // effectively unauthenticated (and likely silently rejected by Reverb,
      // since _channelName already carries the "private-" prefix). Using the
      // matching private-channel method actually triggers the auth handshake.
      final channel = client.subscribeToPrivateChannel(channelName);

      _events = channel.stream.listen((event) {
        if (event.eventName == 'MessageSent') {
          try {
            final data = event.data is String
                ? jsonDecode(event.data as String) as Map<String, dynamic>
                : event.data as Map<String, dynamic>;
            final messageJson = data['message'] as Map<String, dynamic>;
            if (!controller.isClosed) {
              controller.add(MessageModel.fromJson(messageJson));
            }
          } catch (_) {
            // Ignore malformed events
          }
        }
      });
    } catch (e) {
      _controller?.addError(e);
    }
  }

  @override
  void disconnect() {
    _events?.cancel();
    _events = null;
    final channelName = _channelName;
    if (channelName != null) _client?.unsubscribeFromChannel(channelName);
    _controller?.close();
    _controller = null;
    _client = null;
    _channelName = null;
  }
}
