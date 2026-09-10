import 'package:chat_app/feature/call/callsession/call_session.dart';
import 'package:equatable/equatable.dart';

abstract class CallEvent extends Equatable {
  const CallEvent();
  @override
  List<Object?> get props => [];
}

/// User tapped the call icon on the conversation screen.
class CallStartRequested extends CallEvent {
  final String peerId;
  final String peerName;
  final bool isVideo;
  const CallStartRequested({
    required this.peerId,
    required this.peerName,
    this.isVideo = false,
  });
  @override
  List<Object?> get props => [peerId, peerName, isVideo];
}

/// Arrived over the socket: someone is calling us.
class CallInviteReceived extends CallEvent {
  final CallSession session;
  const CallInviteReceived(this.session);
  @override
  List<Object?> get props => [session];
}

/// We tapped accept on the incoming-call screen.
class CallAccepted extends CallEvent {
  const CallAccepted();
}

/// We tapped decline, or the peer declined our outgoing call.
class CallDeclined extends CallEvent {
  const CallDeclined();
}

/// Either side hung up.
class CallEndRequested extends CallEvent {
  const CallEndRequested();
}

/// Remote peer ended the call (arrived over the socket).
class CallEndedRemotely extends CallEvent {
  const CallEndedRemotely();
}

class CallMuteToggled extends CallEvent {
  const CallMuteToggled();
}

class CallSpeakerToggled extends CallEvent {
  const CallSpeakerToggled();
}

/// Internal: fired from the Agora event handler (onUserJoined) once the
/// remote party's audio stream actually joins the channel. Not meant to be
/// added from the UI.
class CallPeerConnected extends CallEvent {
  final int remoteUid;
  const CallPeerConnected(this.remoteUid);
  @override
  List<Object?> get props => [remoteUid];
}

/// Internal: 1-second ticker while CallConnected, drives the on-screen timer.
class CallElapsedTicked extends CallEvent {
  const CallElapsedTicked();
}
