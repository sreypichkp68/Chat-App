import 'dart:async';
import 'package:chat_app/core/service/token_storage.dart';
import 'package:chat_app/feature/call/callsession/call_session.dart';
import 'package:chat_app/feature/call/callsignalingsevice/call_invite_payload.dart';
import 'package:chat_app/feature/call/domain/reposity/call_repository.dart';
import 'package:chat_app/feature/call/presentation/bloc/call.bloc.dart';
import 'package:chat_app/feature/call/presentation/bloc/call_event.dart';
import 'package:chat_app/feature/call/presentation/bloc/call_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _Signaling extends CallSignalingService {
  _Signaling() : super(TokenStorage());
  final checked = Completer<void>();
  final result = Completer<bool>();
  @override
  Future<bool> hasCallEnded(String callId) {
    if (!checked.isCompleted) checked.complete();
    return result.future;
  }
}
class _Repository implements CallRepository {
  int writes = 0;
  @override
  Future<void> endCall({required String callId, required String status}) async {
    writes++;
  }
}
const session = CallSession(callId: 'call', channelName: 'channel', peerId: 'peer',
  peerName: 'Peer', direction: CallDirection.incoming, status: CallStatus.ringing,
  isVideo: false);
void main() {
  for (final accepted in [false, true]) {
    test(accepted ? 'late status response cannot end an accepted call'
        : 'missing hangup event is recovered from server status', () async {
      final signaling = _Signaling();
      final repository = _Repository();
      final bloc = CallBloc(currentUserId: 'me', currentUserName: 'Me',
        signaling: signaling, callRepository: repository);
      addTearDown(bloc.close);
      final ringing = bloc.stream.firstWhere((s) => s is CallIncomingRinging);
      bloc.add(const CallInviteReceived(session));
      await ringing;
      await signaling.checked.future.timeout(const Duration(seconds: 4));
      if (accepted) {
        final connected = bloc.stream.firstWhere((s) => s is CallConnected);
        bloc.add(const CallPeerConnected(42));
        await connected;
        signaling.result.complete(true);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(bloc.state, isA<CallConnected>());
      } else {
        final finished = bloc.stream.firstWhere((s) => s is CallFinished);
        signaling.result.complete(true);
        await finished.timeout(const Duration(seconds: 1));
      }
      expect(repository.writes, 0);
    });
  }
}
