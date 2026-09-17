import 'dart:io';

import 'package:chat_app/core/service/injection_container.dart';
import 'package:chat_app/core/service/token_storage.dart';
import 'package:chat_app/feature/call/presentation/bloc/call.bloc.dart';
import 'package:chat_app/feature/call/presentation/bloc/call_event.dart';
import 'package:chat_app/feature/call/presentation/screen/call_screen.dart';
import 'package:chat_app/feature/message/domain/entity/message_entity.dart';
import 'package:chat_app/feature/message/presentation/bloc/message_bloc.dart';
import 'package:chat_app/feature/message/presentation/bloc/message_event.dart';
import 'package:chat_app/feature/message/presentation/bloc/message_state.dart';
import 'package:chat_app/feature/message/presentation/widget/about_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class ConversationScreen extends StatefulWidget {
  final int conversationId;
  final String participantId;
  final String participantName;
  final bool isGroup;

  const ConversationScreen({
    super.key,
    required this.conversationId,
    required this.participantId,
    required this.participantName,
    this.isGroup = false,
  });

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _composer = TextEditingController();
  final _scrollController = ScrollController();
  final Set<int> _seenMessageIds = {};
  bool _hasLoadedInitialMessages = false;
  late final MessageBloc _messageBloc;
  final _imagePicker = ImagePicker();
  late final CallBloc _callBloc;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _messageBloc = sl<MessageBloc>()
      ..add(MessageLoadRequested(conversationId: widget.conversationId));
    _callBloc = sl<CallBloc>();
    sl<TokenStorage>().getUserId().then((id) {
      if (mounted) setState(() => _currentUserId = id);
    });
  }

  @override
  void dispose() {
    _composer.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  void _send() {
    final content = _composer.text.trim();
    if (content.isEmpty && _pendingImage == null) return;
    _messageBloc.add(
      MessageSendRequested(
        conversationId: widget.conversationId,
        content: content,
        messageType: _pendingImage != null ? 'image' : 'text',
        imageFile: _pendingImage,
      ),
    );

    _composer.clear();
    setState(() => _pendingImage = null);
  }

  File? _pendingImage;

  Future<void> _pickImage() async {
    final XFile? picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;
    setState(() => _pendingImage = File(picked.path));
  }

  void _removePendingImage() {
    setState(() => _pendingImage = null);
  }

  void _startCall({bool isVideo = true}) {
    _callBloc.add(
      CallStartRequested(
        peerId: widget.participantId,
        peerName: widget.participantName,
        isVideo: isVideo,
      ),
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: _callBloc,
          child: CallScreen(initialPeerName: widget.participantName),
        ),
      ),
    );
  }

  Future<void> _showMessageActions(MessageEntity message) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _MessageActionSheet(
        message: message,
        onCopy: () async {
          await Clipboard.setData(ClipboardData(text: message.content));
          if (!mounted) return;
          Navigator.of(sheetContext).pop();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Message copied')));
        },
        onReplay: () {
          _composer.text = message.content;
          Navigator.of(sheetContext).pop();
        },
        onForward: () {
          Navigator.of(sheetContext).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Forwarding will be available soon.')),
          );
        },
        onDelete: () {
          Navigator.of(sheetContext).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message deletion will be available soon.'),
            ),
          );
        },
      ),
    );
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  String _formatMessageTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => _messageBloc,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF303238)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          titleSpacing: 0,
          title: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: widget.isGroup
                ? null
                : () {
                    AboutUser.show(
                      context,
                      participantName: widget.participantName,
                      participantId: widget.participantId,
                    );
                  },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF34C471),
                    child: widget.isGroup
                        ? const Icon(Icons.group, color: Colors.white, size: 19)
                        : Text(
                            widget.participantName.isEmpty
                                ? '?'
                                : widget.participantName[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.participantName,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: widget.isGroup
              ? []
              : [
                  IconButton(
                    icon: const Icon(
                      Icons.call_outlined,
                      color: Color(0xFF53565C),
                    ),
                    onPressed: () => _startCall(isVideo: false),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.videocam_outlined,
                      color: Color(0xFF53565C),
                    ),
                    onPressed: () => _startCall(isVideo: true),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Color(0xFF53565C)),
                    onPressed: () {
                      AboutUser.show(
                        context,
                        participantName: widget.participantName,
                        participantId: widget.participantId,
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                ],
        ),
        body: Column(
          children: [
            Expanded(
              child: BlocConsumer<MessageBloc, MessageState>(
                listener: (_, state) {
                  if (state is! MessageLoaded) return;
                  _scrollToLatest();

                  final newIncomingMessages = state.messages.where((message) {
                    final incoming = widget.isGroup
                        ? message.id > 0 &&
                              _currentUserId != null &&
                              message.senderId.toString() != _currentUserId
                        : message.senderId.toString() == widget.participantId;
                    return _hasLoadedInitialMessages &&
                        !_seenMessageIds.contains(message.id) &&
                        incoming;
                  }).toList();
                  _seenMessageIds.addAll(
                    state.messages.map((message) => message.id),
                  );
                  _hasLoadedInitialMessages = true;

                  if (newIncomingMessages.isEmpty) return;
                  final message = newIncomingMessages.last;
                  Get.snackbar(
                    widget.participantName,
                    message.content,
                    snackPosition: SnackPosition.TOP,
                    duration: const Duration(seconds: 2),
                    backgroundColor: const Color(0xFF21B95F),
                    colorText: Colors.white,
                    icon: const Icon(
                      Icons.message_outlined,
                      color: Colors.white,
                    ),
                  );
                },
                builder: (context, state) {
                  if (state is MessageLoading || state is MessageInitial)
                    return const Center(child: CircularProgressIndicator());
                  if (state is MessageError)
                    return Center(
                      child: Text('Could not load messages: ${state.message}'),
                    );
                  final messages = state is MessageLoaded
                      ? state.messages
                      : const <MessageEntity>[];
                  if (messages.isEmpty)
                    return const Center(
                      child: Text('Say hello to start the conversation.'),
                    );
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                    itemCount: messages.length + 1,
                    itemBuilder: (_, index) {
                      if (index == 0)
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 18),
                            child: Chip(
                              label: Text(
                                'Today',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        );

                      final message = messages[index - 1];
                      final sentByMe = widget.isGroup
                          ? message.id < 0 ||
                                message.senderId.toString() == _currentUserId
                          : message.senderId.toString() != widget.participantId;

                      return _MessageBubble(
                        message: message,
                        sentByMe: sentByMe,
                        senderName: widget.isGroup && !sentByMe
                            ? message.senderName ?? 'User ${message.senderId}'
                            : null,
                        time: _formatMessageTime(message.createdAt),
                        onTap: () => _showMessageActions(message),
                        onCallBack: message.isCallLog && !widget.isGroup
                            ? () {
                                final callType =
                                    message.metadata?['call_type'] as String?;
                                _startCall(isVideo: callType == 'video');
                              }
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_pendingImage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _pendingImage!,
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: -6,
                              right: -6,
                              child: GestureDetector(
                                onTap: _removePendingImage,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        const Icon(Icons.add, color: Color(0xFF565A60)),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: _pickImage,
                          child: const Icon(
                            Icons.photo,
                            color: Color(0xFF565A60),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.camera_alt_rounded,
                          color: Color(0xFF565A60),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.mic_none, color: Color(0xFF565A60)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _composer,
                            textCapitalization: TextCapitalization.sentences,
                            onSubmitted: (_) => _send(),
                            decoration: InputDecoration(
                              hintText: _pendingImage != null
                                  ? 'Add a caption'
                                  : 'Message',
                              filled: true,
                              fillColor: const Color(0xFFF4F5F6),
                              suffixIcon: const Icon(
                                Icons.emoji_emotions_outlined,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(
                            Icons.send_rounded,
                            color: Color(0xFF34C471),
                          ),
                          onPressed: _send,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.sentByMe,
    this.senderName,
    required this.time,
    required this.onTap,
    this.onCallBack,
  });
  final MessageEntity message;
  final bool sentByMe;
  final String? senderName;
  final String time;
  final VoidCallback onTap;
  final VoidCallback? onCallBack;

  @override
  Widget build(BuildContext context) {
    if (message.messageType == 'call_log') {
      return _CallLogBubble(
        message: message,
        sentByMe: sentByMe,
        time: time,
        onCallBack: onCallBack,
      );
    }

    final bubbleColor = sentByMe
        ? const Color(0xFF21B95F)
        : const Color(0xFFF1F2F4);
    final textColor = sentByMe ? Colors.white : const Color(0xFF4A4D53);
    final hasImage =
        (message.imageUrl?.isNotEmpty ?? false) ||
        (message.localImagePath?.isNotEmpty ?? false);

    return Align(
      alignment: sentByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: sentByMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (senderName != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 5),
                child: Text(
                  senderName!,
                  style: const TextStyle(
                    color: Color(0xFF4A4D53),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            GestureDetector(
              onTap: onTap,
              onLongPress: onTap,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * .72,
                ),
                padding: hasImage
                    ? const EdgeInsets.all(4)
                    : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: hasImage ? Colors.transparent : bubbleColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasImage)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: message.localImagePath != null
                            ? Image.file(
                                File(message.localImagePath!),
                                width: 220,
                                height: 220,
                                fit: BoxFit.cover,
                              )
                            : message.imageUrl != null
                            ? Image.network(
                                message.imageUrl!,
                                width: 220,
                                height: 220,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      width: 220,
                                      height: 220,
                                      color: const Color(0xFFF1F2F4),
                                      child: const Icon(
                                        Icons.broken_image_outlined,
                                      ),
                                    ),
                              )
                            : Container(
                                width: 220,
                                height: 220,
                                color: const Color(0xFFF1F2F4),
                                child: const Icon(
                                  Icons.image_not_supported_outlined,
                                ),
                              ),
                      ),
                    if (message.content.isNotEmpty)
                      Padding(
                        padding: hasImage
                            ? const EdgeInsets.fromLTRB(8, 6, 8, 4)
                            : EdgeInsets.zero,
                        child: Text(
                          message.content,
                          style: TextStyle(
                            color: hasImage
                                ? const Color(0xFF4A4D53)
                                : textColor,
                            fontSize: 15,
                            height: 1.25,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: const TextStyle(color: Color(0xFF9DA1A7), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _CallLogBubble extends StatelessWidget {
  const _CallLogBubble({
    required this.message,
    required this.sentByMe,
    required this.time,
    this.onCallBack,
  });

  final MessageEntity message;
  final bool sentByMe;
  final String time;
  final VoidCallback? onCallBack;

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final status = message.callStatus ?? 'ended';
    final isVideo = message.callType == 'video';
    final duration = message.callDurationSeconds;
    final isMissedForMe = status == 'missed' && !sentByMe;

    late final IconData icon;
    late final Color iconColor;
    late final String label;

    switch (status) {
      case 'missed':
        icon = Icons.call_missed_rounded;
        iconColor = const Color(0xFFE0433C);
        label = sentByMe
            ? 'No answer'
            : 'Missed ${isVideo ? 'video ' : ''}call';
        break;
      case 'declined':
        icon = Icons.call_end_rounded;
        iconColor = const Color(0xFFE0433C);
        label = sentByMe ? 'Call declined' : 'You declined';
        break;
      case 'ended':
      default:
        icon = isVideo ? Icons.videocam_rounded : Icons.call_rounded;
        iconColor = const Color(0xFF6E7178);
        label = (duration != null && duration > 0)
            ? 'Call · ${_formatDuration(duration)}'
            : 'Call ended';
        break;
    }

    return Align(
      alignment: sentByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: sentByMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F2F4),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: iconColor),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF4A4D53),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (isMissedForMe && onCallBack != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onCallBack,
                      child: const Icon(
                        Icons.call_rounded,
                        size: 16,
                        color: Color(0xFF21B95F),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: const TextStyle(color: Color(0xFF9DA1A7), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageActionSheet extends StatelessWidget {
  const _MessageActionSheet({
    required this.message,
    required this.onCopy,
    required this.onReplay,
    required this.onForward,
    required this.onDelete,
  });

  final MessageEntity message;
  final VoidCallback onCopy;
  final VoidCallback onReplay;
  final VoidCallback onForward;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 18),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                message.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF303238),
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'React',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children:
                  [
                      '🔥',
                      '🙌',
                      '😭',
                      '🙈',
                      '🙏',
                      '🤔',
                      '✨',
                    ].map((emoji) => _ReactionButton(emoji: emoji)).toList()
                    ..add(const _ReactionButton(icon: Icons.add_rounded)),
            ),
            const SizedBox(height: 10),
            _ActionRow(label: 'Copy', icon: Icons.copy_outlined, onTap: onCopy),
            _ActionRow(
              label: 'Replay',
              icon: Icons.reply_rounded,
              onTap: onReplay,
            ),
            _ActionRow(
              label: 'Forward',
              icon: Icons.forward_rounded,
              onTap: onForward,
            ),
            _ActionRow(
              label: 'Delete',
              icon: Icons.delete_outline_rounded,
              onTap: onDelete,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({this.emoji, this.icon})
    : assert(emoji != null || icon != null);

  final String? emoji;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reactions will be available soon.')),
      ),
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child: emoji != null
              ? Text(emoji!, style: const TextStyle(fontSize: 23))
              : const Icon(
                  Icons.add_rounded,
                  size: 21,
                  color: Color(0xFF6E7178),
                ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isLast = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF292B30),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(icon, size: 23, color: const Color(0xFF292B30)),
              ],
            ),
          ),
        ),
        if (!isLast) const Divider(height: 1, color: Color(0xFFEDEDEF)),
      ],
    );
  }
}
