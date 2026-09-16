import 'package:chat_app/feature/call/presentation/bloc/call.bloc.dart';
import 'package:chat_app/feature/call/presentation/bloc/call_event.dart';
import 'package:chat_app/feature/call/presentation/bloc/call_state.dart';
import 'package:chat_app/feature/call/presentation/screen/call_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Push with Navigator when a `CallIncomingRinging` state appears (see
/// `global_call_listener.dart`). Pops itself once the call resolves.
class IncomingCallScreen extends StatelessWidget {
  const IncomingCallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CallBloc, CallState>(
      listener: (context, state) {
        final session = switch (state) {
          CallConnecting(session: final session) => session,
          CallConnected(session: final session) => session,
          _ => null,
        };
        if (session != null) {
          final callBloc = context.read<CallBloc>();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: callBloc,
                child: CallScreen(initialPeerName: session.peerName),
              ),
            ),
          );
        } else if (state is CallFinished || state is CallIdle) {
          if (Navigator.of(context, rootNavigator: true).canPop()) {
            Navigator.of(context, rootNavigator: true).pop();
          }
        }
      },
      builder: (context, state) {
        final peerName = switch (state) {
          CallIncomingRinging(session: final session) => session.peerName,
          CallConnecting(session: final session) => session.peerName,
          CallConnected(session: final session) => session.peerName,
          _ => 'Unknown',
        };
        return Scaffold(
          backgroundColor: const Color(0xFF14171B),
          body: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 48),
                CircleAvatar(
                  radius: 48,
                  backgroundColor: const Color(0xFF34C471),
                  child: Text(
                    peerName.isEmpty ? '?' : peerName[0].toUpperCase(),
                    style: const TextStyle(fontSize: 36, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  peerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Incoming voice call…',
                  style: TextStyle(color: Color(0xFFAEB2B8), fontSize: 15),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 40,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _CallActionButton(
                        color: const Color(0xFFE0473A),
                        icon: Icons.call_end_rounded,
                        label: 'Decline',
                        onTap: () =>
                            context.read<CallBloc>().add(const CallDeclined()),
                      ),
                      _CallActionButton(
                        color: const Color(0xFF34C471),
                        icon: Icons.call_rounded,
                        label: 'Accept',
                        onTap: () =>
                            context.read<CallBloc>().add(const CallAccepted()),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CallActionButton extends StatelessWidget {
  const _CallActionButton({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    );
  }
}
