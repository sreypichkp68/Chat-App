import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:chat_app/core/constants/api_entpoint.dart';
import 'package:chat_app/feature/call/callsession/call_session.dart';
import 'package:chat_app/feature/call/callsignalingsevice/call_invite_payload.dart';
import 'package:chat_app/feature/call/domain/reposity/call_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'call_event.dart';
import 'call_state.dart';

String get _agoraAppId => dotenv.env['AGORA_APP_ID'] ?? '';

class CallBloc extends Bloc<CallEvent, CallState> {
  CallBloc({
    required this.currentUserId,
    required this.currentUserName,
    required CallSignalingService signaling,
    required CallRepository callRepository,
  }) : _callRepository = callRepository,
       _signaling = signaling,
       super(const CallIdle()) {
    on<CallStartRequested>(_onStartRequested);
    on<GroupCallStartRequested>(_onGroupStartRequested);
    on<CallInviteReceived>(_onInviteReceived);
    on<CallAccepted>(_onAccepted);
    on<CallDeclined>(_onDeclined);
    on<CallEndRequested>(_onEndRequested);
    on<CallEndedRemotely>(_onEndedRemotely);
    on<CallMuteToggled>(_onMuteToggled);
    on<CallSpeakerToggled>(_onSpeakerToggled);
    on<CallPeerConnected>(_onPeerConnected);
    on<CallPeerDisconnected>(_onPeerDisconnected);
    on<CallElapsedTicked>(_onElapsedTicked);
    _ringingStateSub = stream.listen(_watchIncomingCall);

    // registerCallBloc starts signaling after these listeners are attached,
    // so an invite arriving during connection setup is not lost.
    _inviteSub = _signaling.onIncomingInvite.listen((payload) {
      add(
        CallInviteReceived(
          CallSession(
            callId: payload.callId,
            channelName: payload.channelName,
            peerId: payload.callerId,
            peerName: payload.groupName ?? payload.callerName,
            direction: CallDirection.incoming,
            status: CallStatus.ringing,
            isVideo: payload.isVideo,
            groupId: payload.groupId,
          ),
        ),
      );
    });
    _acceptedSub = _signaling.onAccepted.listen((callId) {
      final s = state;
      if (s is CallOutgoingRinging && s.session.groupId == null && s.session.callId == callId) {
        add(const CallAccepted());
      }
    });
    _declinedSub = _signaling.onDeclined.listen((callId) {
      final s = state;
      if (s is CallOutgoingRinging && s.session.groupId == null && s.session.callId == callId) {
        add(const CallDeclined());
      }
    });
    _endedSub = _signaling.onEnded.listen((callId) {
      final s = state;
      final activeId = s is CallConnected
          ? s.session.callId
          : s is CallOutgoingRinging
          ? s.session.callId
          : s is CallIncomingRinging
          ? s.session.callId
          : s is CallConnecting
          ? s.session.callId
          : null;
      final ignoreMemberEnd = s is CallConnected &&
          s.session.groupId != null &&
          s.session.direction == CallDirection.outgoing;
      if (!ignoreMemberEnd && activeId == callId) {
        add(const CallEndedRemotely());
      }
    });
  }

  final String currentUserId;
  final String currentUserName;
  final CallSignalingService _signaling;
  RtcEngine? get engine => _engine;
  RtcEngine? _engine;
  Timer? _elapsedTimer;
  Timer? _ringingPoll, _ringingTimeout;
  StreamSubscription<CallState>? _ringingStateSub;
  StreamSubscription? _inviteSub, _acceptedSub, _declinedSub, _endedSub;
  final CallRepository _callRepository;
  final Set<String> _loggedCallIds = {};
  final Map<String, Set<String>> _sentGroupInvites = {};

  void _watchIncomingCall(CallState next) {
    _ringingPoll?.cancel();
    _ringingTimeout?.cancel();
    if (next is! CallIncomingRinging) return;
    final callId = next.session.callId;
    bool stillRinging() => !isClosed &&
        state is CallIncomingRinging &&
        (state as CallIncomingRinging).session.callId == callId;
    var checking = false;
    _ringingPoll = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (checking || !stillRinging()) return;
      checking = true;
      try {
        if (await _signaling.hasCallEnded(callId) && stillRinging()) {
          // The server already saved the final status; do not write it again.
          _loggedCallIds.add(callId);
          add(const CallEndedRemotely());
        }
      } catch (error) {
        log('Call status check failed: $error');
      } finally {
        checking = false;
      }
    });
    // Match the notification's expiry, including when connectivity is lost.
    _ringingTimeout = Timer(const Duration(seconds: 60), () {
      if (stillRinging()) add(const CallEndedRemotely());
    });
  }
  Future<void> _ensureEngine({required bool isVideo}) async {
    if (_engine != null) return;

    final statuses = await [
      Permission.microphone,
      if (isVideo) Permission.camera,
    ].request();

    if (!statuses[Permission.microphone]!.isGranted) {
      throw StateError('Microphone permission was not granted.');
    }
    if (isVideo && !statuses[Permission.camera]!.isGranted) {
      throw StateError('Camera permission was not granted.');
    }

    if (_agoraAppId.isEmpty) {
      throw StateError(
        'AGORA_APP_ID is empty. Run with --dart-define=AGORA_APP_ID=xxx '
        '(see AGORA_SETUP.md).',
      );
    }
    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(appId: _agoraAppId));
    await _engine!.enableAudio();
    if (isVideo) {
      await _engine!.enableVideo();
      await _engine!.startPreview();
    }
    await _engine!.setChannelProfile(
      ChannelProfileType.channelProfileCommunication,
    );

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {},
        onUserJoined: (connection, remoteUid, elapsed) {
          if (!isClosed) add(CallPeerConnected(remoteUid));
        },
        onUserOffline: (connection, remoteUid, reason) {
          final s = state;
          if (!isClosed && s is CallConnected && s.session.groupId != null &&
              s.session.channelName == connection.channelId) {
            add(CallPeerDisconnected(remoteUid));
            return;
          }
          if (!isClosed &&
              s is CallConnected &&
              s.remoteUid == remoteUid &&
              s.session.channelName == connection.channelId) {
            add(const CallEndedRemotely());
          }
        },
        onError: (err, msg) {
          print('AGORA onError: $err  msg: $msg');
          // SDK errors are not peer hang-ups. Some are recoverable; channel
          // setup exceptions and the peer-offline callback handle termination.
        },
      ),
    );
  }

  Future<String> _fetchToken(String channelName, int uid) async {
    final authToken = await _signaling.tokenStorage.getToken();
    final uri = Uri.parse(
      '${ApiEntpoint.callToken}?channelName=$channelName&uid=$uid',
    );
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $authToken',
        'Accept': 'application/json',
      },
    );
    // ignore: avoid_print
    print('TOKEN FETCH: ${response.statusCode} ${response.body}');
    if (response.statusCode != 200) {
      throw StateError('Could not fetch call token (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded['token'] as String;
  }

  int _uidFor(String userId) => userId.hashCode & 0x7fffffff;

  Future<void> _onStartRequested(
    CallStartRequested event,
    Emitter<CallState> emit,
  ) async {
    if (state is! CallIdle) return;
    final callId = '${currentUserId}_${DateTime.now().microsecondsSinceEpoch}';
    final channelName = 'call_$callId';
    final session = CallSession(
      callId: callId,
      channelName: channelName,
      peerId: event.peerId,
      peerName: event.peerName,
      direction: CallDirection.outgoing,
      status: CallStatus.ringing,
      isVideo: event.isVideo,
    );
    log(
      'CALL STARTED: me=$currentUserId → peer=${event.peerId} '
      '(${event.peerName}) callId=$callId',
    );
    emit(CallOutgoingRinging(session));

    try {
      await _signaling.sendInvite(
        CallInvitePayload(
          callId: callId,
          callerId: currentUserId,
          callerName: currentUserName,
          calleeId: event.peerId,
          channelName: channelName,
          isVideo: event.isVideo,
        ),
      );
      await _ensureEngine(isVideo: session.isVideo);
      final uid = _uidFor(currentUserId);
      final token = await _fetchToken(channelName, uid);
      await _engine!.joinChannel(
        token: token,
        channelId: channelName,
        uid: uid,
        options: ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
          publishCameraTrack: session.isVideo,
          publishMicrophoneTrack: true,
          autoSubscribeVideo: session.isVideo,
          autoSubscribeAudio: true,
        ),
      );
    } catch (e, st) {
      // ignore: avoid_print
      print('CALL START ERROR: $e\n$st');
      unawaited(_notifyRemoteCallEnded(callId, status: 'missed'));
      emit(CallFinished('Could not start call: $e'));
      await _teardownEngine();
      await Future.delayed(const Duration(seconds: 2));
      if (!isClosed) emit(const CallIdle());
    }
  }

  Future<void> _onGroupStartRequested(
    GroupCallStartRequested event,
    Emitter<CallState> emit,
  ) async {
    if (state is! CallIdle) return;
    final members = event.memberIds.toSet()..remove(currentUserId);
    if (members.isEmpty) return;
    final callId = '${currentUserId}_${DateTime.now().microsecondsSinceEpoch}';
    final channelName = 'group_call_$callId';
    final inviteIds = members.map((id) => '${callId}_$id').toList();
    _sentGroupInvites[callId] = <String>{};
    final session = CallSession(
      callId: callId,
      channelName: channelName,
      peerId: event.groupId.toString(),
      peerName: event.groupName,
      direction: CallDirection.outgoing,
      status: CallStatus.ringing,
      isVideo: event.isVideo,
      groupId: event.groupId,
      inviteCallIds: inviteIds,
    );
    emit(CallOutgoingRinging(session));
    try {
      await _ensureEngine(isVideo: session.isVideo);
      final uid = _uidFor(currentUserId);
      final token = await _fetchToken(channelName, uid);
      await _engine!.joinChannel(
        token: token,
        channelId: channelName,
        uid: uid,
        options: ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
          publishCameraTrack: session.isVideo,
          publishMicrophoneTrack: true,
          autoSubscribeVideo: session.isVideo,
          autoSubscribeAudio: true,
        ),
      );
      final inviteErrors = <String>[];
      final results = await Future.wait(members.toList().asMap().entries.map((entry) async {
        try {
          await _signaling.sendInvite(CallInvitePayload(
            callId: inviteIds[entry.key],
            callerId: currentUserId,
            callerName: currentUserName,
            calleeId: entry.value,
            channelName: channelName,
            isVideo: event.isVideo,
            groupId: event.groupId,
            groupName: event.groupName,
          ));
          _sentGroupInvites[callId]?.add(inviteIds[entry.key]);
          final current = state;
          final stillActive = current is CallOutgoingRinging && current.session.callId == callId ||
              current is CallConnected && current.session.callId == callId;
          if (!stillActive) {
            unawaited(_notifyRemoteCallEnded(inviteIds[entry.key], status: 'missed'));
          }
          return true;
        } catch (error) {
          log('Could not invite group member ${entry.value}: $error');
          inviteErrors.add(error.toString());
          return false;
        }
      }));
      if (results.every((sent) => !sent)) {
        throw StateError(inviteErrors.isEmpty
            ? 'Could not invite any group members.'
            : inviteErrors.first);
      }
    } catch (error) {
      _sentGroupInvites.remove(callId);
      final current = state;
      final stillActive = current is CallOutgoingRinging && current.session.callId == callId ||
          current is CallConnected && current.session.callId == callId;
      if (!stillActive) return;
      emit(CallFinished('Could not start group call: $error'));
      await _teardownEngine();
      await Future.delayed(const Duration(seconds: 2));
      if (!isClosed) emit(const CallIdle());
    }
  }

  void _onInviteReceived(CallInviteReceived event, Emitter<CallState> emit) {
    if (state is! CallIdle) {
      _signaling.sendDecline(event.session.callId, event.session.peerId);
      return;
    }
    emit(CallIncomingRinging(event.session));
  }

  Future<void> _onAccepted(CallAccepted event, Emitter<CallState> emit) async {
    final s = state;
    if (s is CallIncomingRinging) {
      _signaling.sendAccept(s.session.callId, s.session.peerId);
      try {
        await _ensureEngine(isVideo: s.session.isVideo);
        final uid = _uidFor(currentUserId);
        final token = await _fetchToken(s.session.channelName, uid);

        emit(CallConnecting(s.session, uid));

        await _engine!.joinChannel(
          token: token,
          channelId: s.session.channelName,
          uid: uid,
          options: ChannelMediaOptions(
            clientRoleType: ClientRoleType.clientRoleBroadcaster,
            channelProfile: ChannelProfileType.channelProfileCommunication,
            publishCameraTrack: s.session.isVideo,
            publishMicrophoneTrack: true,
            autoSubscribeVideo: s.session.isVideo,
            autoSubscribeAudio: true,
          ),
        );
      } catch (e, st) {
        print('CALL ACCEPT ERROR: $e\n$st');
        unawaited(_notifyRemoteCallEnded(s.session.callId, status: 'missed'));
        emit(CallFinished('Could not connect: $e'));
        await _teardownEngine();
        await Future.delayed(const Duration(seconds: 2));
        if (!isClosed) emit(const CallIdle());
      }
    }
  }

  Future<void> _onDeclined(CallDeclined event, Emitter<CallState> emit) async {
    final s = state;

    if (s is CallIncomingRinging) {
      _signaling.sendDecline(s.session.callId, s.session.peerId);
      await _logCallEnd(s.session.callId, 'declined');
    }
    await _teardownEngine();
    emit(const CallFinished('Declined'));
    await Future.delayed(const Duration(seconds: 2));
    if (!isClosed) emit(const CallIdle());
  }

  Future<void> _onEndRequested(
    CallEndRequested event,
    Emitter<CallState> emit,
  ) async {
    if (state is CallIdle || state is CallFinished) return;
    final s = state;
    final session = s is CallConnected
        ? s.session
        : s is CallOutgoingRinging
        ? s.session
        : s is CallIncomingRinging
        ? s.session
        : s is CallConnecting
        ? s.session
        : null;
    if (session != null) {
      // Never wait for the API request before closing this device's call.
      // A slow/unavailable server previously left the UI and Agora session
      // active until the HTTP socket timed out.
      final callIds = session.groupId != null && session.direction == CallDirection.outgoing
          ? (_sentGroupInvites.remove(session.callId)?.toList() ?? <String>[])
          : session.inviteCallIds.isEmpty
          ? [session.callId]
          : session.inviteCallIds;
      for (final id in callIds) {
        unawaited(_notifyRemoteCallEnded(
          id,
          status: s is CallConnected ? 'ended' : 'missed',
        ));
      }
    }
    emit(const CallFinished('Call ended'));
    await _teardownEngine();
    await Future.delayed(const Duration(seconds: 2));
    if (!isClosed) emit(const CallIdle());
  }

  Future<void> _onEndedRemotely(
    CallEndedRemotely event,
    Emitter<CallState> emit,
  ) async {
    if (state is CallIdle || state is CallFinished) return;
    final s = state;
    final session = s is CallConnected
        ? s.session
        : s is CallOutgoingRinging
        ? s.session
        : s is CallIncomingRinging
        ? s.session
        : s is CallConnecting
        ? s.session
        : null;
    if (session != null) {
      unawaited(
        _logCallEnd(session.callId, s is CallConnected ? 'ended' : 'missed'),
      );
    }
    emit(const CallFinished('Call ended'));
    await _teardownEngine();
    await Future.delayed(const Duration(seconds: 2));
    if (!isClosed) emit(const CallIdle());
  }

  Future<void> _onMuteToggled(
    CallMuteToggled event,
    Emitter<CallState> emit,
  ) async {
    final s = state;
    if (s is! CallConnected) return;
    final next = !s.isMuted;
    await _engine?.muteLocalAudioStream(next);
    emit(s.copyWith(isMuted: next));
  }

  Future<void> _onSpeakerToggled(
    CallSpeakerToggled event,
    Emitter<CallState> emit,
  ) async {
    final s = state;
    if (s is! CallConnected) return;
    final next = !s.isSpeakerOn;
    await _engine?.setEnableSpeakerphone(next);
    emit(s.copyWith(isSpeakerOn: next));
  }

  void _onPeerConnected(CallPeerConnected event, Emitter<CallState> emit) {
    final s = state;
    if (s is CallConnected) {
      if (s.session.groupId != null && !s.remoteUids.contains(event.remoteUid)) {
        emit(s.copyWith(remoteUids: [...s.remoteUids, event.remoteUid]));
      }
      return;
    }
    final session = s is CallOutgoingRinging
        ? s.session
        : s is CallIncomingRinging
        ? s.session
        : s is CallConnecting
        ? s.session
        : null;
    if (session == null) return;

    emit(
      CallConnected(
        session,
        remoteUid: event.remoteUid,
        remoteUids: [event.remoteUid],
        localUid: _uidFor(currentUserId),
      ),
    );
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isClosed) add(const CallElapsedTicked());
    });
  }

  void _onPeerDisconnected(CallPeerDisconnected event, Emitter<CallState> emit) {
    final s = state;
    if (s is! CallConnected || s.session.groupId == null) return;
    final remaining = s.remoteUids.where((uid) => uid != event.remoteUid).toList();
    emit(s.copyWith(
      remoteUid: remaining.isEmpty ? 0 : remaining.first,
      remoteUids: remaining,
    ));
  }

  void _onElapsedTicked(CallElapsedTicked event, Emitter<CallState> emit) {
    final s = state;
    if (s is CallConnected) {
      emit(s.copyWith(elapsed: s.elapsed + const Duration(seconds: 1)));
    }
  }

  Future<void> _teardownEngine() async {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    await _engine?.leaveChannel();
    await _engine?.release();
    _engine = null;
  }

  Future<void> _notifyRemoteCallEnded(
    String callId, {
    required String status,
  }) async {
    try {
      await _signaling.sendEnd(callId, status: status);
      log('CALL END NOTIFIED: callId=$callId');
    } catch (error, stackTrace) {
      // The local call has already closed. Keep this failure visible without
      // allowing it to prevent the terminal CallFinished state.
      log('CALL END NOTIFICATION FAILED: $error', stackTrace: stackTrace);
    }
  }

  Future<void> _logCallEnd(String callId, String status) async {
    if (_loggedCallIds.contains(callId)) return; // ← បន្ថែម: ការពារ log ស្ទួន
    _loggedCallIds.add(callId);
    try {
      await _callRepository.endCall(callId: callId, status: status);
    } catch (e) {
      log('Failed to log call end: $e');
    }
  }

  @override
  Future<void> close() async {
    await _ringingStateSub?.cancel();
    _ringingPoll?.cancel();
    _ringingTimeout?.cancel();
    await _inviteSub?.cancel();
    await _acceptedSub?.cancel();
    await _declinedSub?.cancel();
    await _endedSub?.cancel();
    await _teardownEngine();
    await _signaling.dispose();
    return super.close();
  }
}
