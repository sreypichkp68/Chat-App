import 'package:chat_app/core/service/notification_service.dart';
import 'package:chat_app/feature/call/incomingcall/incoming_call_screen.dart';
import 'package:chat_app/feature/call/presentation/bloc/call.bloc.dart';
import 'package:chat_app/feature/call/presentation/bloc/call_event.dart';
import 'package:chat_app/feature/call/presentation/bloc/call_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class GlobalCallListener extends StatelessWidget {
  const GlobalCallListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<CallBloc, CallState>(
      listener: (context, state) {
        print('GLOBAL LISTENER: state = $state');

        if (state is CallIncomingRinging) {
          print('GLOBAL LISTENER: navigating to IncomingCallScreen');
          NotificationService.instance.showIncomingCall(state.session.peerName);

          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: context.read<CallBloc>(),
                child: const IncomingCallScreen(),
              ),
            ),
          );
        } else if (state is CallConnected ||
            state is CallFinished ||
            state is CallDeclined ||
            state is CallIdle) {
          NotificationService.instance.cancelIncomingCall();
        }
      },
      child: child,
    );
  }
}
