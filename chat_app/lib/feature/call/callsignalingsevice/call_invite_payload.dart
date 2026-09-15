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
    final client = await ReverbClient.instance(
      host: ApiEntpoint.reverbHost,
      port: ApiEntpoint.reverbPort,
      appKey: ApiEntpoint.reverbKey,
      authEndpoint: ApiEntpoint.broadcastingAuth, 
      useTLS:
          true, // FIX: Railway's port 443 is TLS-only; this was defaulting to false (ws://),
      // which caused "Connection closed before full header was received".
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
        print('BROADCASTING AUTH: ${response.statusCode} ${response.body}');
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return decoded.map((key, value) => MapEntry(key, value.toString()));
      },
    );
    _client = client;
    await client.connect();

    // Wait for the client's internal state to actually reach `connected`
    // before subscribing — connect() can resolve slightly before this flag
    // flips, causing "not connected to server" on an immediate subscribe.
    await client.onConnectionStateChange.firstWhere(
      (state) => state == ConnectionState.connected,
    );

    print('REVERB CONNECTED for user $currentUserId');

    final channel = client.subscribeToPrivateChannel(
      'private-calls.$currentUserId',
    );
    try {
      await channel.subscribe();
      print('SUBSCRIBED to private-calls.$currentUserId');
    } catch (e, st) {
      print('SUBSCRIBE ERROR: $e\n$st');
    }

    // NOTE: removed the redundant 'App\\Events\\CallInvited' listener —
    // broadcastAs() on the backend already aliases the event to 'CallInvited',
    // so only one listener is needed.
    channel.on('CallInvited').listen((event) {
      print('CALL INVITED EVENT RECEIVED: ${event.data}');
      final data = event.data is String
          ? jsonDecode(event.data as String) as Map<String, dynamic>
          : event.data as Map<String, dynamic>;
      _incomingInviteController.add(CallInvitePayload.fromJson(data));
    });

    channel.on('CallDeclined').listen((event) {
      final data = event.data is String
          ? jsonDecode(event.data as String) as Map<String, dynamic>
          : event.data as Map<String, dynamic>;
      _declinedController.add(data['callId'].toString());
    });

    channel.on('CallEnded').listen((event) {
      final data = event.data is String
          ? jsonDecode(event.data as String) as Map<String, dynamic>
          : event.data as Map<String, dynamic>;
      _endedController.add(data['callId'].toString());
    });
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
  Future<void> sendEnd(String callId, String peerId) =>
      _post(ApiEntpoint.callEnd, {'callId': callId, 'peerId': peerId});

  Future<void> _post(String url, Map<String, dynamic> body) async {
    final token = await tokenStorage.getToken();
    await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
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
