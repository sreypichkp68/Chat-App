enum CallDirection { outgoing, incoming }

enum CallStatus { ringing, connected, ended, declined, missed, failed }

/// Represents one voice call between the current user and a peer.
/// [channelName] is the Agora channel both sides join; [callId] is the
/// signaling id used to correlate invite/accept/decline/end socket events.
class CallSession {
  final String callId;
  final String channelName;
  final String peerId;
  final String peerName;
  final CallDirection direction;
  final CallStatus status;
  final bool isVideo;

  const CallSession({
    required this.callId,
    required this.channelName,
    required this.peerId,
    required this.peerName,
    required this.direction,
    required this.status,
    required this.isVideo,
  });

  CallSession copyWith({CallStatus? status}) {
    return CallSession(
      callId: callId,
      channelName: channelName,
      peerId: peerId,
      peerName: peerName,
      isVideo: isVideo,
      direction: direction,
      status: status ?? this.status,
    );
  }
}
