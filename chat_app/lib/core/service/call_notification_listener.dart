import 'dart:async';

import 'package:chat_app/feature/call/presentation/bloc/call_state.dart';
import 'package:flutter/foundation.dart';

/// Owned by the authenticated session, independently of the visible screens.
class CallNotificationListener {
  CallNotificationListener({
    required Stream<CallState> states,
    required Future<void> Function(String name, {bool isVideo}) show,
    required Future<void> Function() cancel,
  }) : _cancel = cancel {
    _subscription = states.listen((state) {
      if (state is CallIncomingRinging) {
        _enqueue(
          () => show(state.session.peerName, isVideo: state.session.isVideo),
        );
      } else if (state is CallConnecting ||
          state is CallConnected ||
          state is CallFinished ||
          state is CallIdle) {
        _enqueue(cancel);
      }
    });
  }

  final Future<void> Function() _cancel;
  late final StreamSubscription<CallState> _subscription;
  Future<void> _pending = Future<void>.value();

  void _enqueue(Future<void> Function() operation) {
    // A fast hang-up must cancel AFTER an in-flight show finishes.
    _pending = _pending.then((_) => operation()).catchError((Object error) {
      debugPrint('Call notification failed: $error');
    });
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    _enqueue(_cancel);
    await _pending;
  }
}
