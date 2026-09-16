import 'dart:async';
import 'dart:convert';

import 'package:chat_app/core/constants/api_entpoint.dart';
import 'package:chat_app/core/service/token_storage.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:http/http.dart' as http;
import 'package:pusher_reverb_flutter/pusher_reverb_flutter.dart';
class CallInvitePayload {
  final String callId;
  final String callerId;
  final String callerName;
  final bool isVideo;
  final String calleeId;
  final String channelName;

  CallInvitePayload({
    required this.callId,
    required this.isVideo,
    required this.callerId,
    required this.callerName,
    required this.calleeId,
    required this.channelName,
  });

  factory CallInvitePayload.fromJson(Map<String, dynamic> json) {
    return CallInvitePayload(
      callId: json['callId'].toString(),
      callerId: json['callerId'].toString(),
      callerName: json['callerName']?.toString() ?? '',
      calleeId: json['calleeId'].toString(),
      channelName: json['channelName'].toString(),
      isVideo: json['isVideo'] == true || json['isVideo']?.toString() == '1',
    );
  }

  Map<String, dynamic> toJson() => {
    'callId': callId,
    'callerId': callerId,
    'callerName': callerName,
    'isVideo': isVideo,
    'calleeId': calleeId,
    'channelName': channelName,
  };
}

class CallSignalingService {
  CallSignalingService(this.tokenStorage);

  final TokenStorage tokenStorage;
  ReverbClient? _client;
  ReverbClient get client => _client!;

  final _incomingInviteController =
      StreamController<CallInvitePayload>.broadcast();
  final _acceptedController = StreamController<String>.broadcast();
  final _declinedController = StreamController<String>.broadcast();
  final _endedController = StreamController<String>.broadcast();

  Stream<CallInvitePayload> get onIncomingInvite =>
      _incomingInviteController.stream;
  Stream<String> get onAccepted => _acceptedController.stream;
  Stream<String> get onDeclined => _declinedController.stream;
  Stream<String> get onEnded => _endedController.stream;

  Future<void> start(String currentUserId) async {
    try {
      final client = await ReverbClient.instance(
        host: ApiEntpoint.reverbHost,
        port: ApiEntpoint.reverbPort,
        appKey: ApiEntpoint.reverbKey,
        authEndpoint: ApiEntpoint.broadcastingAuth,
        useTLS: true,
        pingInterval: const Duration(seconds: 15),

        authorizer: (channelName, socketId) async {
          final token = await tokenStorage.getToken();

          if (token == null || token.isEmpty) {
            throw Exception('Bearer token not found');
          }

          print(
            'CALL AUTHORIZER: '
            'channel=$channelName '
            'socket=$socketId',
          );

          return {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          };
        },

        onConnected: (socketId) {
          print('CALL REVERB CONNECTED: $socketId');
        },
        onDisconnected: () => debugPrint('CALL REVERB DISCONNECTED'),
        onReconnecting: () => debugPrint('CALL REVERB RECONNECTING'),

        onError: (error) {
          print('CALL REVERB ERROR: $error');
        },
      );

      _client = client;

      await client.connect();

      await client.onConnectionStateChange.firstWhere(
        (state) => state == ConnectionState.connected,
      );

      print('REVERB CONNECTED for user $currentUserId');

      final channelName = 'private-calls.$currentUserId';

      print('SUBSCRIBING TO: $channelName');

      final channel = client.subscribeToPrivateChannel(channelName);

      // subscribeToPrivateChannel() starts the package's asynchronous auth and
      // subscription flow itself. A second `channel.subscribe()` returns as
      // soon as the channel is already "subscribing", so it cannot be used as
      // proof that Reverb accepted the subscription.
      channel.addStateListener((state) {
        if (state == ChannelState.subscribed) {
          print('✅ SUBSCRIBED TO: $channelName');
        } else if (state == ChannelState.unsubscribed) {
          print('❌ CALL CHANNEL UNSUBSCRIBED: $channelName');
        }
      });

      // Debug ALL received events
      channel.stream.listen(
        (event) {
          print(
            '🔥 CALL CHANNEL EVENT: '
            '${event.eventName}',
          );

          print(
            '🔥 CALL CHANNEL DATA: '
            '${event.data}',
          );
        },
        onError: (error) {
          print(
            '❌ CALL CHANNEL STREAM ERROR: '
            '$error',
          );
        },
      );

      channel.on('CallInvited').listen((event) {
        print(
          '📞 CALL INVITED RECEIVED: '
          '${event.data}',
        );

        try {
          final data = event.data is String
              ? jsonDecode(event.data as String) as Map<String, dynamic>
              : Map<String, dynamic>.from(event.data as Map);

          final payload = CallInvitePayload.fromJson(data);

          print(
            '📞 Incoming call '
            'from ${payload.callerName}',
          );

          _incomingInviteController.add(payload);
        } catch (e, st) {
          print(
            '❌ CallInvited parse error: '
            '$e\n$st',
          );
        }
      });

      // You were missing this listener
      channel.on('CallAccepted').listen((event) {
        print('✅ CALL ACCEPTED: ${event.data}');

        final data = event.data is String
            ? jsonDecode(event.data as String) as Map<String, dynamic>
            : Map<String, dynamic>.from(event.data as Map);

        _acceptedController.add(data['callId'].toString());
      });

      channel.on('CallDeclined').listen((event) {
        print('❌ CALL DECLINED: ${event.data}');

        final data = event.data is String
            ? jsonDecode(event.data as String) as Map<String, dynamic>
            : Map<String, dynamic>.from(event.data as Map);

        _declinedController.add(data['callId'].toString());
      });

      channel.on('CallEnded').listen((event) {
        print('☎️ CALL ENDED: ${event.data}');

        final data = event.data is String
            ? jsonDecode(event.data as String) as Map<String, dynamic>
            : Map<String, dynamic>.from(event.data as Map);

        _endedController.add(data['callId'].toString());
      });
    } catch (e, st) {
      print(
        '❌ CALL SIGNALING START ERROR: '
        '$e\n$st',
      );
    }
  }

  Future<void> sendInvite(CallInvitePayload payload) async {
    print(
      'CALL INVITE SENDING: from=${payload.callerId} to=${payload.calleeId} '
      'callId=${payload.callId} channel=${payload.channelName}',
    );
    final token = await tokenStorage.getToken();
    final response = await http.post(
      Uri.parse(ApiEntpoint.callInvite),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload.toJson()),
    );
    print('CALL INVITE RESPONSE: ${response.statusCode} ${response.body}');
  }

  Future<void> sendAccept(String callId, String peerId) =>
      _post(ApiEntpoint.callAccept, {'callId': callId, 'peerId': peerId});
  Future<void> sendDecline(String callId, String peerId) =>
      _post(ApiEntpoint.callDecline, {'callId': callId, 'peerId': peerId});
  Future<void> sendEnd(String callId, {required String status}) =>
      _post(ApiEntpoint.callEnd(callId), {'status': status});

  Future<bool> hasCallEnded(String callId) async {
    final token = await tokenStorage.getToken();
    final response = await http.get(
      Uri.parse('${ApiEntpoint.url}/calls/${Uri.encodeComponent(callId)}'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) {
      throw StateError('Call status check failed (${response.statusCode})');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['call_id'] == callId &&
        (data['ended_at'] != null ||
            const ['ended', 'declined', 'missed'].contains(data['status']));
  }

  Future<void> _post(String url, Map<String, dynamic> body) async {
    final token = await tokenStorage.getToken();
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    debugPrint('CALL API: ${response.statusCode} $url ${response.body}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Call API failed (${response.statusCode}): ${response.body}',
      );
    }
  }

  Future<void> dispose() async {
    await runZonedGuarded(
      () {
        _client?.disconnect();
      },
      (error, stack) {
        debugPrint('Ignored teardown error in ReverbClient.disconnect: $error');
      },
    );
    _incomingInviteController.close();
    _acceptedController.close();
    _declinedController.close();
    _endedController.close();
  }
}
