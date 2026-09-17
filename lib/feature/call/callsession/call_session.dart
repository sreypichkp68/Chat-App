enum CallDirection { outgoing, incoming }

enum CallStatus { ringing, connected, ended, declined, missed, failed }

/// Represents a direct call or a group call in one Agora channel.
/// Group callers send one invite per member, recorded in [inviteCallIds].
class CallSession {
  final String callId;
  final String channelName;
  final String peerId;
  final String peerName;
  final CallDirection direction;
  final CallStatus status;
  final bool isVideo;
  final int? groupId;
  final List<String> inviteCallIds;

  const CallSession({
    required this.callId,
    required this.channelName,
    required this.peerId,
    required this.peerName,
    required this.direction,
    required this.status,
    required this.isVideo,
    this.groupId,
    this.inviteCallIds = const [],
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
      groupId: groupId,
      inviteCallIds: inviteCallIds,
    );
  }
}
