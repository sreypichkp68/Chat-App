import 'dart:async';
import 'dart:convert';
import 'package:chat_app/core/constants/api_entpoint.dart';
import 'package:chat_app/core/service/token_storage.dart';
import 'package:chat_app/feature/message/data/model/message_model.dart';
import 'package:http/http.dart' as http;
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

  @override
  Stream<MessageModel> connect({required int conversationId}) {
    _controller = StreamController<MessageModel>.broadcast();
    _channelName = 'private-conversation.$conversationId';

    _initClient();

    return _controller!.stream;
  }

 Future<void> _initClient() async {
    try {
      // Await the ReverbClient.instance properly since it's asynchronous
      final client = await ReverbClient.instance(
        host: ApiEntpoint.reverbHost,
        port: ApiEntpoint.reverbPort,
        appKey: ApiEntpoint.reverbKey,
        authorizer: (channelName, socketId) async {
          final token = await tokenStorage.getToken();
          final response = await http.post(
            Uri.parse(ApiEntpoint.broadcastingAuth),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
            body: {'socket_id': socketId, 'channel_name': channelName},
          );
            print(
            'MESSAGE BROADCASTING AUTH: ${response.statusCode} ${response.body}',
          );

          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          return decoded.map((key, value) => MapEntry(key, value.toString()));
        },
      );

      _client = client;
      await client.connect();

      // Now 'client' is fully resolved, and privateChannel will work seamlessly
      final channel = client.subscribeToChannel(_channelName!);
      await channel.subscribe();

      channel.stream.listen((event) {
        if (event.eventName == 'MessageSent') {
          try {
            final data = event.data is String
                ? jsonDecode(event.data as String) as Map<String, dynamic>
                : event.data as Map<String, dynamic>;
            final messageJson = data['message'] as Map<String, dynamic>;
            _controller?.add(MessageModel.fromJson(messageJson));
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
    _client?.disconnect();
    _controller?.close();
    _controller = null;
    _client = null;
    _channelName = null;
  }
}
