import 'dart:async';
import 'dart:io';
import 'package:chat_app/feature/message/data/datasource/read_receipt_datasource.dart';
import 'package:chat_app/feature/message/presentation/widget/read_receipt_avatar.dart';
import 'take_photo_screen.dart';
import 'package:chat_app/feature/message/data/datasource/message_datasource.dart';
import 'package:chat_app/feature/group/domain/entity/group_entity.dart';
import 'package:chat_app/core/widget/profile_avatar_image.dart';

import 'package:chat_app/core/service/injection_container.dart';
import 'package:chat_app/core/service/token_storage.dart';
import 'package:chat_app/feature/call/presentation/bloc/call.bloc.dart';
import 'package:chat_app/feature/call/presentation/bloc/call_event.dart';
import 'package:chat_app/feature/call/presentation/bloc/call_state.dart';
import 'package:chat_app/feature/call/presentation/screen/call_screen.dart';
import 'package:chat_app/feature/group/presentation/screen/group_members_screen.dart';
import 'package:chat_app/feature/group/data/datasource/group_remote_data_source.dart';
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
import 'package:permission_handler/permission_handler.dart';

class ConversationScreen extends StatefulWidget {
  final int conversationId;
  final String participantId;
  final String participantName;
  final String? avatarUrl;
  final bool isGroup;

  const ConversationScreen({
    super.key,
    required this.conversationId,
    required this.participantId,
    required this.participantName,
    this.avatarUrl,
    this.isGroup = false,
  });

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen>
    with WidgetsBindingObserver {
  final _messageViewportKey = GlobalKey();
  final Map<int, GlobalKey> _messageKeys = {};
  Timer? _receiptTimer;
  int _recipientReadId = 0;
  int _markedReadId = 0;
  bool _loadingReceipts = false;
  bool _markingRead = false;

  bool get _chatIsVisible =>
      mounted &&
      !widget.isGroup &&
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
      ModalRoute.of(context)?.isCurrent == true;

  Future<void> _refreshReceipts() async {
    if (!_chatIsVisible || _loadingReceipts) return;
    _loadingReceipts = true;
    try {
      final receipts = await sl<ReadReceiptDataSource>().getReceipts(
        widget.conversationId,
      );
      final readId = receipts[widget.participantId] ?? 0;
      if (mounted && readId > _recipientReadId) {
        setState(() {
          _recipientReadId = readId;
        });
      }
    } catch (_) {
      // Keep the last confirmed receipt and retry on the next tick.
    } finally {
      _loadingReceipts = false;
    }
  }

  Future<void> _markVisibleMessagesRead() async {
    if (!_chatIsVisible || _markingRead) return;
    final viewport = _messageViewportKey.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return;
    final top = viewport.localToGlobal(Offset.zero).dy;
    final bottom = top + viewport.size.height;
    var visibleId = _markedReadId;
    final state = _messageBloc.state;
    if (state is! MessageLoaded) return;
    for (final message in state.messages) {
      if (message.id <= visibleId ||
          message.senderId.toString() != widget.participantId) {
        continue;
      }
      final box = _messageKeys[message.id]?.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final messageBottom = box.localToGlobal(Offset(0, box.size.height)).dy;
      if (messageBottom > top && messageBottom <= bottom + 1) {
        visibleId = message.id;
      }
    }
    if (visibleId <= _markedReadId) return;
    _markingRead = true;
    try {
      await sl<ReadReceiptDataSource>().markRead(
        widget.conversationId, visibleId,
      );
      _markedReadId = visibleId;
    } catch (_) {
      // Failed acknowledgements are retried; never infer that a send was seen.
    } finally {
      _markingRead = false;
    }
  }

  void _scheduleReadCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_markVisibleMessagesRead());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleReadCheck();
      unawaited(_refreshReceipts());
    }
  }
  final _composer = TextEditingController();
  final _scrollController = ScrollController();
  final Set<int> _seenMessageIds = {};
  bool _hasLoadedInitialMessages = false;
  int? _lastVisibleMessageId;
  late final MessageBloc _messageBloc;
  final _imagePicker = ImagePicker();
  late final CallBloc _callBloc;
  String? _currentUserId;
  GroupEntity? _headerGroup;

  Future<void> _loadGroupAvatar() async {
    try {
      final group = await sl<GroupRemoteDataSource>().getGroup(
        widget.conversationId,
      );
      if (mounted) setState(() => _headerGroup = group);
    } catch (_) {
      // Keep the existing avatar when group details are unavailable.
    }
  }

  Widget _headerAvatar() {
    final photo = profileAvatarImage(
      _headerGroup?.avatarUrl ?? widget.avatarUrl,
    );
    final members = _headerGroup?.members ?? const <GroupMemberEntity>[];
    if (widget.isGroup && photo == null && members.isNotEmpty) {
      return SizedBox(
        width: 36,
        height: 36,
        child: Stack(
          children: [
            for (var index = 0; index < members.length.clamp(0, 2); index++)
              Positioned(
                left: index == 0 ? 0 : null,
                right: index == 1 ? 0 : null,
                top: index == 0 ? 0 : null,
                bottom: index == 1 ? 0 : null,
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: const Color(0xFF34C471),
                  foregroundImage: profileAvatarImage(members[index].avatarUrl),
                  onForegroundImageError:
                      profileAvatarImage(members[index].avatarUrl) == null
                      ? null
                      : (_, error) {},
                  child: Text(
                    members[index].name.isEmpty
                        ? '?'
                        : members[index].name[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
          ],
        ),
      );
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: const Color(0xFF34C471),
      foregroundImage: photo,
      onForegroundImageError: photo == null ? null : (_, error) {},
      child: widget.isGroup
          ? const Icon(Icons.group, color: Colors.white, size: 19)
          : Text(
              widget.participantName.isEmpty
                  ? '?'
                  : widget.participantName[0].toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_scheduleReadCheck);
    if (!widget.isGroup) {
      _receiptTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        unawaited(_refreshReceipts());
        unawaited(_markVisibleMessagesRead());
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_refreshReceipts());
      });
    }
    _messageBloc = sl<MessageBloc>()
      ..add(MessageLoadRequested(conversationId: widget.conversationId));
    _callBloc = sl<CallBloc>();
    if (widget.isGroup) _loadGroupAvatar();
    sl<TokenStorage>().getUserId().then((id) {
      if (mounted) setState(() => _currentUserId = id);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _receiptTimer?.cancel();
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
  bool _pickingImage = false;

  Future<void> _pickImage({ImageSource source = ImageSource.gallery}) async {
    if (_pickingImage) return;
    setState(() => _pickingImage = true);
    try {
      // Android requires permission because CAMERA is declared for video calls.
      if (source == ImageSource.camera && Platform.isAndroid) {
        final permission = await Permission.camera.request();
        if (!mounted) return;
        if (!permission.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Allow camera access to take a photo.'),
              action: permission.isPermanentlyDenied
                  ? SnackBarAction(
                      label: 'Settings',
                      onPressed: () {
                        openAppSettings();
                      },
                    )
                  : null,
            ),
          );
          return;
        }
      }
      if (!mounted) return;
      final path = source == ImageSource.camera
          ? await Navigator.of(context).push<String>(
              MaterialPageRoute(builder: (_) => const TakePhotoScreen()),
            )
          : (await _imagePicker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 80,
            ))?.path;
      if (path == null || !mounted) return;
      setState(() => _pendingImage = File(path));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == ImageSource.camera
                ? 'Could not open the camera. Check camera access and try again.'
                : 'Could not open the photo library. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  void _removePendingImage() {
    setState(() => _pendingImage = null);
  }

  Future<void> _startCall({bool isVideo = true}) async {
    if (_callBloc.state is! CallIdle) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Finish the current call first.')),
      );
      return;
    }
    if (widget.isGroup) {
      try {
        final group = await sl<GroupRemoteDataSource>().getGroup(
          widget.conversationId,
        );
        final currentUserId =
            _currentUserId ?? await sl<TokenStorage>().getUserId();
        final members = group.members
            .where((member) => member.id.toString() != currentUserId)
            .map((member) => member.id.toString())
            .toList();
        if (!mounted || _callBloc.state is! CallIdle) return;
        if (members.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add another member before calling.')),
          );
          return;
        }
        _callBloc.add(
          GroupCallStartRequested(
            groupId: widget.conversationId,
            groupName: widget.participantName,
            memberIds: members,
            isVideo: isVideo,
          ),
        );
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start group call: $error')),
        );
        return;
      }
    } else {
      _callBloc.add(
        CallStartRequested(
          peerId: widget.participantId,
          peerName: widget.participantName,
          isVideo: isVideo,
        ),
      );
    }
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
    if (message.metadata?['is_unsent'] == true) return;
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
        onDelete:
            message.id > 0 && message.senderId.toString() == _currentUserId
            ? () {
                Navigator.of(sheetContext).pop();
                _deleteMessage(message);
              }
            : null,
      ),
    );
  }

  Future<void> _deleteMessage(MessageEntity message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text(
          'Your message will be replaced with "Unsend Message" for everyone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await sl<MessageDataSource>().deleteMessage(message.id);
      if (!mounted) return;
      _messageBloc.add(
        MessageLoadRequested(conversationId: widget.conversationId),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  void _scrollToLatest({required bool jump}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (jump) {
        _scrollController.jumpTo(target);
        return;
      }
      if ((target - _scrollController.offset).abs() < 16) return;
      _scrollController.animateTo(
        target,
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
    final scheme = Theme.of(context).colorScheme;
    final background = Theme.of(context).scaffoldBackgroundColor;
    return BlocProvider(
      create: (_) => _messageBloc,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: background,
          surfaceTintColor: background,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: scheme.onSurface),
            onPressed: () => Navigator.of(context).pop(),
          ),
          titleSpacing: 0,
          title: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: widget.isGroup
                ? () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          GroupMembersScreen(groupId: widget.conversationId),
                    ),
                  )
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
                children: [
                  _headerAvatar(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.participantName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.call_outlined, color: scheme.onSurfaceVariant),
              onPressed: () => _startCall(isVideo: false),
            ),
            IconButton(
              icon: Icon(
                Icons.videocam_outlined,
                color: scheme.onSurfaceVariant,
              ),
              onPressed: () => _startCall(isVideo: true),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: Icon(Icons.more_vert, color: scheme.onSurfaceVariant),
              onPressed: () {
                if (widget.isGroup) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          GroupMembersScreen(groupId: widget.conversationId),
                    ),
                  );
                } else {
                  AboutUser.show(
                    context,
                    participantName: widget.participantName,
                    participantId: widget.participantId,
                  );
                }
              },
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              key: _messageViewportKey,
              child: BlocConsumer<MessageBloc, MessageState>(
                listener: (_, state) {
                  if (state is! MessageLoaded) return;
                  final latestId = state.messages.isEmpty
                      ? null
                      : state.messages.last.id;
                  final isInitialLoad = !_hasLoadedInitialMessages;
                  final isNearBottom =
                      !_scrollController.hasClients ||
                      _scrollController.position.extentAfter < 80;
                  if (latestId != null &&
                      latestId != _lastVisibleMessageId &&
                      (isInitialLoad || isNearBottom)) {
                    _scrollToLatest(jump: isInitialLoad);
                  }
                  _lastVisibleMessageId = latestId;

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
                    message.displayContent,
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
                  final seenMessageId = widget.isGroup
                      ? null
                      : latestSeenMessageId(
                          messages, widget.participantId, _recipientReadId,
                        );
                  _scheduleReadCheck();
                  if (messages.isEmpty)
                    return const Center(
                      child: Text('Say hello to start the conversation.'),
                    );
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                    itemCount: messages.length,
                    itemBuilder: (_, index) {
                      final message = messages[index];
                      final date = message.createdAt.toLocal();
                      final startsDay =
                          index == 0 ||
                          !DateUtils.isSameDay(
                            date,
                            messages[index - 1].createdAt.toLocal(),
                          );
                      final sentByMe = widget.isGroup
                          ? message.id < 0 ||
                                message.senderId.toString() == _currentUserId
                          : message.senderId.toString() != widget.participantId;

                      final bubble = _MessageBubble(
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
                      return Column(
                        key: _messageKeys.putIfAbsent(
                          message.id, () => GlobalKey(),
                        ),
                        children: [
                          if (startsDay)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 18),
                                child: Chip(
                                  label: Text(
                                    MaterialLocalizations.of(
                                      context,
                                    ).formatMediumDate(date),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                            ),
                          bubble,
                          if (message.id == seenMessageId)
                            ReadReceiptAvatar(
                              name: widget.participantName,
                              avatarUrl: widget.avatarUrl,
                            ),
                        ],
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
                        Icon(Icons.add, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: _pickingImage ? null : () => _pickImage(),
                          child: Icon(
                            Icons.photo,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          tooltip: 'Take photo',
                          onPressed: _pickingImage
                              ? null
                              : () => _pickImage(source: ImageSource.camera),
                          icon: Icon(
                            Icons.camera_alt_rounded,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.mic_none, color: scheme.onSurfaceVariant),
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
                              fillColor: scheme.surfaceContainerHigh,
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

    final scheme = Theme.of(context).colorScheme;
    final bubbleColor = sentByMe
        ? const Color(0xFF21B95F)
        : scheme.surfaceContainerHigh;
    final textColor = sentByMe ? Colors.white : scheme.onSurface;
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
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
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
                    if (message.displayContent.isNotEmpty)
                      Padding(
                        padding: hasImage
                            ? const EdgeInsets.fromLTRB(8, 6, 8, 4)
                            : EdgeInsets.zero,
                        child: Text(
                          message.displayContent,
                          style: TextStyle(
                            color: hasImage ? scheme.onSurface : textColor,
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
    final scheme = Theme.of(context).colorScheme;
    final status = message.callStatus ?? 'ended';
    final isGroupCall = message.isGroupCallLog;
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
            : 'Missed ${isGroupCall ? 'group ' : ''}${isVideo ? 'video ' : ''}call';
        break;
      case 'declined':
        icon = Icons.call_missed_rounded;
        iconColor = const Color(0xFFE0433C);
        label = isGroupCall ? 'Missed group call' : 'Missed call';
        break;
      case 'ended':
      default:
        icon = isVideo ? Icons.videocam_rounded : Icons.call_rounded;
        iconColor = const Color(0xFF6E7178);
        final callName = isGroupCall ? 'Group call' : 'Call';
        label = (duration != null && duration > 0)
            ? '$callName · ${_formatDuration(duration)}'
            : '$callName ended';
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
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: iconColor),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color: status == 'missed' || status == 'declined'
                          ? iconColor
                          : scheme.onSurface,
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
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 18),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
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
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                message.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurface,
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
            if (onDelete != null)
              _ActionRow(
                label: 'Delete',
                icon: Icons.delete_outline_rounded,
                onTap: onDelete!,
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
    final color = Theme.of(context).colorScheme.onSurface;
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
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(icon, size: 23, color: color),
              ],
            ),
          ),
        ),
        if (!isLast) const Divider(height: 1, color: Color(0xFFEDEDEF)),
      ],
    );
  }
}
