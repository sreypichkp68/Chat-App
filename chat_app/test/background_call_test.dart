import 'dart:async';

import 'package:chat_app/core/service/call_notification_listener.dart';
import 'package:chat_app/core/service/token_storage.dart';
import 'package:chat_app/feature/call/callsession/call_session.dart';
import 'package:chat_app/feature/call/callsignalingsevice/call_invite_payload.dart';
import 'package:chat_app/feature/call/domain/reposity/call_repository.dart';
import 'package:chat_app/feature/call/goblecall/global_call_listener.dart';
import 'package:chat_app/feature/call/incomingcall/incoming_call_screen.dart';
import 'package:chat_app/feature/call/presentation/bloc/call.bloc.dart';
import 'package:chat_app/feature/call/presentation/bloc/call_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

const session = CallSession(
  callId: 'background-call',
  channelName: 'channel',
  peerId: 'caller',
  peerName: 'Caller',
  direction: CallDirection.incoming,
  status: CallStatus.ringing,
  isVideo: false,
);

class _Repository implements CallRepository {
  @override
  Future<void> endCall({
    required String callId,
    required String status,
  }) async {}
}

class _CallBloc extends CallBloc {
  _CallBloc()
    : super(
        currentUserId: 'receiver',
        currentUserName: 'Receiver',
        signaling: CallSignalingService(TokenStorage()),
        callRepository: _Repository(),
      );

  void receive(CallState next) => emit(next);
}

void main() {
  test(
    'notifies without widgets and orders hang-up after pending show',
    () async {
      final states = StreamController<CallState>();
      final showing = Completer<void>();
      final started = Completer<void>();
      final cancelled = Completer<void>();
      final operations = <String>[];
      final listener = CallNotificationListener(
        states: states.stream,
        show: (name, {bool isVideo = false}) async {
          operations.add('show $name');
          started.complete();
          await showing.future;
        },
        cancel: () async {
          operations.add('cancel');
          if (!cancelled.isCompleted) cancelled.complete();
        },
      );
      states.add(const CallIncomingRinging(session));
      await started.future;
      states.add(const CallFinished('Ended'));
      await Future<void>.delayed(Duration.zero);
      expect(operations, ['show Caller']);
      showing.complete();
      await cancelled.future;
      expect(operations, ['show Caller', 'cancel']);
      await listener.dispose();
      await states.close();
    },
  );

  test(
    'accepting cancels notification and logout detaches the listener',
    () async {
      final states = StreamController<CallState>();
      final cancelled = Completer<void>();
      var shows = 0;
      final listener = CallNotificationListener(
        states: states.stream,
        show: (_, {bool isVideo = false}) async {
          shows++;
        },
        cancel: () async {
          if (!cancelled.isCompleted) cancelled.complete();
        },
      );
      states.add(const CallIncomingRinging(session));
      states.add(const CallConnecting(session, 1));
      await cancelled.future;
      expect(shows, 1);
      await listener.dispose();
      states.add(const CallIncomingRinging(session));
      await states.close();
      expect(shows, 1);
    },
  );

  for (final ended in [false, true]) {
    testWidgets(
      ended
          ? 'does not reopen a call ended in background'
          : 'opens one incoming screen on resume after a background invite',
      (tester) async {
        final bloc = _CallBloc();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<CallBloc>.value(
              value: bloc,
              child: const GlobalCallListener(
                child: Scaffold(body: Text('Home')),
              ),
            ),
          ),
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        bloc.receive(const CallIncomingRinging(session));
        await tester.idle();
        expect(find.byType(IncomingCallScreen), findsNothing);
        if (ended) {
          bloc.receive(const CallFinished('Ended'));
        await tester.idle();
        }
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(IncomingCallScreen),
          ended ? findsNothing : findsOneWidget,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(IncomingCallScreen),
          ended ? findsNothing : findsOneWidget,
        );
        if (!ended) {
          bloc.receive(const CallFinished('Caller hung up'));
          await tester.pumpAndSettle();
          expect(find.byType(IncomingCallScreen), findsNothing);
          expect(find.text('Home'), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(bloc.close);
      },
    );
  }
}


