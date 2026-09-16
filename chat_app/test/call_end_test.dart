import 'dart:async';

import 'package:chat_app/core/service/token_storage.dart';
import 'package:chat_app/feature/call/callsession/call_session.dart';
import 'package:chat_app/feature/call/callsignalingsevice/call_invite_payload.dart';
import 'package:chat_app/feature/call/domain/reposity/call_repository.dart';
import 'package:chat_app/feature/call/presentation/bloc/call.bloc.dart';
import 'package:chat_app/feature/call/presentation/bloc/call_event.dart';
import 'package:chat_app/feature/call/presentation/bloc/call_state.dart';
import 'package:flutter_test/flutter_test.dart';

class PendingCallRepository implements CallRepository {
  final pending = Completer<void>();
  String? status;

  @override
  Future<void> endCall({required String callId, required String status}) {
    this.status = status;
    return pending.future;
  }
}

void main() {
  test(
    'remote hang-up closes a connected call before history API finishes',
    () async {
      final repository = PendingCallRepository();
      final bloc = CallBloc(
        currentUserId: 'me',
        currentUserName: 'Me',
        signaling: CallSignalingService(TokenStorage()),
        callRepository: repository,
      );
      final ringing = bloc.stream.firstWhere((s) => s is CallIncomingRinging);
      bloc.add(
        const CallInviteReceived(
          CallSession(
            callId: 'call-1',
            channelName: 'channel-1',
            peerId: 'peer',
            peerName: 'Peer',
            direction: CallDirection.incoming,
            status: CallStatus.ringing,
            isVideo: true,
          ),
        ),
      );
      await ringing;
      final connected = bloc.stream.firstWhere((s) => s is CallConnected);
      bloc.add(const CallPeerConnected(42));
      await connected;

      final finished = bloc.stream.firstWhere((s) => s is CallFinished);
      bloc.add(const CallEndedRemotely());
      await finished.timeout(const Duration(seconds: 1));
      expect(repository.pending.isCompleted, isFalse);
      expect(repository.status, 'ended');
      repository.pending.complete();
      await bloc.close();
    },
  );
}
