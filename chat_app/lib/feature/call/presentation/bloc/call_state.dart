import 'package:chat_app/feature/call/callsession/call_session.dart';
import 'package:equatable/equatable.dart';

abstract class CallState extends Equatable {
  const CallState();
  @override
  List<Object?> get props => [];
}

class CallIdle extends CallState {
  const CallIdle();
}
class CallConnecting extends CallState {
  final CallSession session;
  final int localUid;
  const CallConnecting(this.session,this.localUid);
}

/// We're calling someone and waiting for them to pick up.
class CallOutgoingRinging extends CallState {
  final CallSession session;
  const CallOutgoingRinging(this.session);
  @override
  List<Object?> get props => [session];
}

/// Someone is calling us.
class CallIncomingRinging extends CallState {
  final CallSession session;
  const CallIncomingRinging(this.session);
  @override
  List<Object?> get props => [session];
}

/// Both sides joined the Agora channel.
class CallConnected extends CallState {
  final CallSession session;
  final int remoteUid;
  final bool isMuted;

  final int localUid;
  final bool isSpeakerOn;
  final Duration elapsed;
  const CallConnected(
    this.session, {
    required this.remoteUid,
    this.isMuted = false,
    required this.localUid,
    this.isSpeakerOn = false,
    this.elapsed = Duration.zero,
  });

  CallConnected copyWith({
    int? remoteUid,
    bool? isMuted,
    bool? isSpeakerOn,
    Duration? elapsed,

  }) {
    return CallConnected(
      session,
       localUid: localUid,
      remoteUid: remoteUid ?? this.remoteUid,
      isMuted: isMuted ?? this.isMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      elapsed: elapsed ?? this.elapsed,
    );
  }

  @override
  List<Object?> get props => [
    session,
    localUid,
    remoteUid,
    isMuted,
    isSpeakerOn,
    elapsed,
  ];
}
/// Terminal state, briefly shown before returning to CallIdle. [reason] is
/// human-readable copy for the call screen ("Call ended", "Declined", etc).
class CallFinished extends CallState {
  final String reason;
  const CallFinished(this.reason);
  @override
  List<Object?> get props => [reason];
}
