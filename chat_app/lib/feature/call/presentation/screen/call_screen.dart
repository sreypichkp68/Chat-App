import 'package:chat_app/feature/message/presentation/widget/conversation_avatar.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:chat_app/feature/call/presentation/bloc/call.bloc.dart';
import 'package:chat_app/core/service/injection_container.dart';
import 'package:chat_app/feature/message/data/datasource/message_datasource.dart';
import 'package:chat_app/feature/message/data/model/message_model.dart';
import 'package:chat_app/feature/message/presentation/screen/conversation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/call_event.dart';
import '../bloc/call_state.dart';

class CallScreen extends StatelessWidget {
  final String initialPeerName;
  const CallScreen({super.key, required this.initialPeerName});

  String _formatElapsed(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: BlocConsumer<CallBloc, CallState>(
        listener: (context, state) {
          if (state is CallFinished && state.reason.startsWith('Could not')) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.reason)));
          }
          if (state is CallFinished || state is CallIdle) {
            if (Navigator.of(context, rootNavigator: true).canPop()) {
              Navigator.of(context, rootNavigator: true).pop();
            }
          }
        },
        builder: (context, state) {
          final isConnected = state is CallConnected;
          final peerName = state is CallOutgoingRinging
              ? state.session.peerName
              : state is CallConnecting
              ? state.session.peerName
              : state is CallConnected
              ? state.session.peerName
              : initialPeerName;
          final statusLabel = switch (state) {
            CallOutgoingRinging() => 'Calling…',
            CallConnecting() => 'Connecting...',
            CallConnected(elapsed: final e) => _formatElapsed(e),
            CallFinished(reason: final r) => r,
            _ => '',
          };
          final isMuted = state is CallConnected ? state.isMuted : false;
          final isSpeakerOn = state is CallConnected
              ? state.isSpeakerOn
              : false;

          final textShadow = isConnected
              ? [const Shadow(blurRadius: 10, color: Colors.black87)]
              : null;

          return Scaffold(
            backgroundColor: const Color(0xFF14171B),
            body: Stack(
              children: [
                if (state is CallConnected &&
                    state.session.isVideo &&
                    state.session.groupId != null)
                  Positioned.fill(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 40, 8, 180),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.8,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      itemCount: state.remoteUids.length + 1,
                      itemBuilder: (context, index) => ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: index == 0
                            ? AgoraVideoView(
                                controller: VideoViewController(
                                  rtcEngine: context.read<CallBloc>().engine!,
                                  canvas: const VideoCanvas(uid: 0),
                                ),
                              )
                            : AgoraVideoView(
                                controller: VideoViewController.remote(
                                  rtcEngine: context.read<CallBloc>().engine!,
                                  canvas: VideoCanvas(
                                    uid: state.remoteUids[index - 1],
                                  ),
                                  connection: RtcConnection(
                                    channelId: state.session.channelName,
                                    localUid: state.localUid,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  )
                else if (state is CallConnected && state.session.isVideo) ...[
                  Positioned.fill(
                    child: AgoraVideoView(
                      controller: VideoViewController.remote(
                        rtcEngine: context.read<CallBloc>().engine!,
                        canvas: VideoCanvas(uid: state.remoteUid),
                        connection: RtcConnection(
                          channelId: state.session.channelName,
                          localUid: state.localUid,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 40,
                    right: 16,
                    width: 100,
                    height: 150,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AgoraVideoView(
                        controller: VideoViewController(
                          rtcEngine: context.read<CallBloc>().engine!,
                          canvas: const VideoCanvas(uid: 0),
                        ),
                      ),
                    ),
                  ),
                ],
                SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 56),
                      // Avatar នៅបង្ហាញតែពេលមិនទាន់ connected ប៉ុណ្ណោះ
                      // (ពេល connected video ជំនួសរួចហើយ)
                      if (state is! CallConnected ||
                          !state.session.isVideo) ...[
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: const Color(0xFF34C471),
                          child: Text(
                            peerName.isEmpty ? '?' : peerName[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 36,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      Text(
                        peerName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isConnected ? 16 : 22,
                          fontWeight: FontWeight.w600,
                          shadows: textShadow,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: const Color(0xFFAEB2B8),
                          fontSize: 15,
                          shadows: textShadow,
                        ),
                      ),
                      if (state is CallConnected &&
                          state.session.groupId != null)
                        Text(
                          '${state.remoteUids.length + 1} in call',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _RoundIconButton(
                              icon: isMuted
                                  ? Icons.mic_off_rounded
                                  : Icons.mic_none_rounded,
                              active: isMuted,
                              onTap: () => context.read<CallBloc>().add(
                                const CallMuteToggled(),
                              ),
                            ),
                            const SizedBox(width: 24),
                            _RoundIconButton(
                              icon: isSpeakerOn
                                  ? Icons.volume_up_rounded
                                  : Icons.volume_down_rounded,
                              active: isSpeakerOn,
                              onTap: () => context.read<CallBloc>().add(
                                const CallSpeakerToggled(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 40),
                        child: InkWell(
                          onTap: () => context.read<CallBloc>().add(
                            const CallEndRequested(),
                          ),
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE0473A),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.call_end_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: active ? Colors.white : const Color(0xFF262A30),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: active ? Colors.black87 : Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  late Future<List<_CallHistoryEntry>> _history = _loadHistory();

  Future<List<_CallHistoryEntry>> _loadHistory() async {
    final source = sl<MessageDataSource>();
    final conversations = await source.getConversations();
    final messagesByConversation = await Future.wait(
      conversations.map(
        (conversation) => source.getMessages(conversationId: conversation.id),
      ),
    );
    final entries = <_CallHistoryEntry>[];
    for (var i = 0; i < conversations.length; i++) {
      for (final message in messagesByConversation[i]) {
        if (message.isCallLog) {
          entries.add(_CallHistoryEntry(conversations[i], message));
        }
      }
    }
    entries.sort((a, b) => b.message.createdAt.compareTo(a.message.createdAt));
    return entries;
  }

  Future<void> _refresh() async {
    final next = _loadHistory();
    setState(() => _history = next);
    try {
      await next;
    } catch (_) {
      // The error state below gives the user a retry action.
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text(
              'Calls',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<_CallHistoryEntry>>(
              future: _history,
              builder: (context, snapshot) {
                if (!snapshot.hasData && !snapshot.hasError) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: TextButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Could not load calls. Retry'),
                    ),
                  );
                }
                final entries = snapshot.data!;
                if (entries.isEmpty) {
                  return const Center(child: Text('No calls yet'));
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final missed =
                          entry.message.callStatus == 'missed' ||
                          entry.message.callStatus == 'declined';
                      final name = entry.conversation.participantName;
                      final date = entry.message.createdAt.toLocal();
                      final localizations = MaterialLocalizations.of(context);
                      final when =
                          '${localizations.formatMediumDate(date)} · '
                          '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
                      final label = missed
                          ? (entry.conversation.isGroup
                                ? 'Missed group call'
                                : 'Missed call')
                          : (entry.conversation.isGroup
                                ? 'Group call'
                                : 'Call');
                      return ListTile(
                        leading: ConversationAvatar(
                          conversation: entry.conversation,
                        ),
                        title: Text(name),
                        subtitle: Text(
                          '$label · $when',
                          style: missed
                              ? const TextStyle(color: Color(0xFFE0433C))
                              : null,
                        ),
                        trailing: Icon(
                          entry.message.callType == 'video'
                              ? Icons.videocam_outlined
                              : Icons.call_outlined,
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ConversationScreen(
                              conversationId: entry.conversation.id,
                              participantId: entry.conversation.participantId,
                              participantName: name,
                              avatarUrl: entry.conversation.avatarUrl,
                              isGroup: entry.conversation.isGroup,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CallHistoryEntry {
  const _CallHistoryEntry(this.conversation, this.message);

  final ConversationSummary conversation;
  final MessageModel message;
}
