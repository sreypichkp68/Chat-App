import 'dart:async';

import 'package:chat_app/core/service/notification_service.dart';
import 'package:chat_app/feature/call/incomingcall/incoming_call_screen.dart';
import 'package:chat_app/feature/call/presentation/bloc/call.bloc.dart';
import 'package:chat_app/feature/call/presentation/bloc/call_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class GlobalCallListener extends StatefulWidget {
  const GlobalCallListener({super.key, required this.child});

  final Widget child;

  @override
  State<GlobalCallListener> createState() => _GlobalCallListenerState();
}

class _GlobalCallListenerState extends State<GlobalCallListener>
    with WidgetsBindingObserver {
  String? _visibleCallId;
  StreamSubscription<void>? _notificationTaps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notificationTaps = NotificationService.instance.incomingCallTaps.listen((_) {
      if (mounted) _showIncomingScreen();
    });
    _scheduleIncomingScreen();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _scheduleIncomingScreen();
  }

  void _scheduleIncomingScreen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showIncomingScreen();
    });
  }

  void _showIncomingScreen() {
    // Only post the notification while paused. Opening it resumes the app.
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    final bloc = context.read<CallBloc>();
    final state = bloc.state;
    if (state is! CallIncomingRinging || _visibleCallId != null) return;
    final callId = state.session.callId;
    _visibleCallId = callId;
    Navigator.of(context, rootNavigator: true)
        .push<void>(
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: bloc,
              child: const IncomingCallScreen(),
            ),
          ),
        )
        .whenComplete(() {
          if (!mounted) return;
          _visibleCallId = null;
          final latest = bloc.state;
          if (latest is CallIncomingRinging &&
              latest.session.callId != callId) {
            _scheduleIncomingScreen();
          }
        });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationTaps?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CallBloc, CallState>(
      listener: (_, state) {
        if (state is CallIncomingRinging) _showIncomingScreen();
      },
      child: widget.child,
    );
  }
}
