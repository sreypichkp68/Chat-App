import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:chat_app/feature/message/presentation/widget/conversation_avatar.dart';

import 'package:chat_app/feature/message/data/datasource/message_datasource.dart';
import 'package:chat_app/feature/searchusers/presentation/bloc/search_user.state.dart';
import 'package:chat_app/feature/searchusers/presentation/bloc/search_user_bloc.dart';
import 'package:chat_app/feature/searchusers/presentation/bloc/search_user_event.dart';
import 'package:chat_app/feature/searchusers/presentation/widget/user_search_tile.dart';
import 'package:chat_app/core/service/injection_container.dart';
import 'package:chat_app/core/service/token_storage.dart';
import 'package:chat_app/feature/friends/data/datasource/friend_request_remote_datasource.dart';
import 'package:chat_app/feature/friends/presentation/screen/friend_requests_screen.dart';
import 'package:chat_app/feature/message/domain/usecase/open_direct_conversation_usecase.dart';
import 'package:chat_app/feature/message/presentation/screen/conversation_screen.dart';
import 'package:chat_app/feature/searchusers/presentation/screen/search_user_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  late Future<int> _friendRequestCount;
  late Future<List<ConversationSummary>> _conversations;
  Timer? _conversationRefreshTimer;
  List<ConversationSummary>? _visibleConversations;
  bool _initialLoadInProgress = true;
  bool _refreshInProgress = false;
  int _conversationRevision = 0;
  final Map<int, String> _lastMessageKeys = {};
  bool _hasConversationSnapshot = false;

  static const _green = Color(0xFF34C471);
  static const _inkFaint = Color(0xFF9AA0A6);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _friendRequestCount = _loadFriendRequestCount();
    _conversations = _loadConversations()
        .then((conversations) {
          _visibleConversations = conversations;
          for (final conversation in conversations) {
            _lastMessageKeys[conversation.id] = _messageKey(conversation);
          }
          _hasConversationSnapshot = true;
          return conversations;
        })
        .whenComplete(() => _initialLoadInProgress = false);
    _conversationRefreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted &&
          !_initialLoadInProgress &&
          ModalRoute.of(context)?.isCurrent == true) {
        _refreshConversations();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshConversations();
    }
  }

  Future<int> _loadFriendRequestCount() async {
    final requests = await sl<FriendRequestRemoteDatasource>()
        .getIncomingRequests();
    return requests.length;
  }

  Future<List<ConversationSummary>> _loadConversations() async {
    final conversations = List<ConversationSummary>.of(
      await sl<MessageDataSource>().getConversations(),
    );
    conversations.sort((a, b) {
      final aTime = a.lastMessageAt;
      final bTime = b.lastMessageAt;
      if (aTime == null && bTime != null) return 1;
      if (aTime != null && bTime == null) return -1;
      final byTime = aTime == null ? 0 : bTime!.compareTo(aTime);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    return conversations;
  }

  DateTime? _chatDay(DateTime? value) {
    if (value == null) return null;
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  String _dayLabel(BuildContext context, DateTime? day, DateTime now) {
    if (day == null) return 'No messages yet';
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return 'Today';
    if (day == DateTime(now.year, now.month, now.day - 1)) {
      return 'Yesterday';
    }
    return MaterialLocalizations.of(context).formatMediumDate(day);
  }

  String _messageKey(ConversationSummary conversation) {
    return '${conversation.lastMessageSenderId}|${conversation.lastMessageAt?.toIso8601String()}|${conversation.lastMessage}';
  }

  Future<void> _refreshConversations() async {
    if (_refreshInProgress) return;
    _refreshInProgress = true;
    final revision = _conversationRevision;
    try {
      final conversations = await _loadConversations();
      final currentUserId = await sl<TokenStorage>().getUserId();
      if (!mounted || revision != _conversationRevision) return;

      final incoming = <ConversationSummary>[];
      for (final conversation in conversations) {
        final key = _messageKey(conversation);
        final previousKey = _lastMessageKeys[conversation.id];
        final isNewIncoming =
            _hasConversationSnapshot &&
            currentUserId != null &&
            previousKey != null &&
            previousKey != key &&
            conversation.lastMessageSenderId != currentUserId;
        if (isNewIncoming) incoming.add(conversation);
        _lastMessageKeys[conversation.id] = key;
      }
      _hasConversationSnapshot = true;

      if (!_sameConversations(_visibleConversations, conversations)) {
        setState(() {
          _visibleConversations = conversations;
          _conversations = Future.value(conversations);
        });
      }

      if (incoming.isNotEmpty) {
        final latest = incoming.first;
        Get.snackbar(
          latest.participantName,
          latest.lastMessage,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF21B95F),
          colorText: Colors.white,
          icon: const Icon(Icons.message_outlined, color: Colors.white),
        );
      }
    } catch (_) {
      // Preserve the visible chat list while a background refresh fails.
    } finally {
      _refreshInProgress = false;
    }
  }

  bool _sameConversations(
    List<ConversationSummary>? previous,
    List<ConversationSummary> next,
  ) {
    if (previous == null || previous.length != next.length) return false;
    for (var i = 0; i < next.length; i++) {
      final before = previous[i];
      final after = next[i];
      if (before.id != after.id ||
          before.participantId != after.participantId ||
          before.participantName != after.participantName ||
          before.avatarUrl != after.avatarUrl ||
          !listEquals(before.memberAvatars, after.memberAvatars) ||
          before.isGroup != after.isGroup ||
          before.isMissedCall != after.isMissedCall ||
          before.isUnread != after.isUnread ||
          before.lastMessage != after.lastMessage ||
          before.lastMessageAt != after.lastMessageAt) {
        return false;
      }
    }
    return true;
  }

  String _formatChatTime(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Future<void> _openConversation(
    FriendContact friend, {
    String? avatarUrl,
  }) async {
    try {
      final conversationId = await sl<OpenDirectConversationUsecase>().call(
        participantId: friend.id,
      );
      if (!mounted) return;
      await _showConversation(
        conversationId: conversationId,
        participantId: friend.id,
        participantName: friend.name,
        avatarUrl: avatarUrl,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open chat: $error')));
    }
  }

  Future<void> _removeChat(ConversationSummary conversation) async {
    if (conversation.isGroup) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove chat?'),
        content: Text(
          'Remove the chat with ${conversation.participantName} from your list? '
          'Your contact and messages are kept. You can chat again anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await sl<MessageDataSource>().removeConversation(
        conversationId: conversation.id,
      );
      if (!mounted) return;
      setState(() {
        _conversationRevision++;
        _visibleConversations = (_visibleConversations ?? [])
            .where((item) => item.id != conversation.id)
            .toList();
        _conversations = Future.value(_visibleConversations!);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chat with ${conversation.participantName} removed.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _showConversation({
    required int conversationId,
    required String participantId,
    required String participantName,
    String? avatarUrl,
    bool isGroup = false,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConversationScreen(
          conversationId: conversationId,
          participantId: participantId,
          participantName: participantName,
          avatarUrl: avatarUrl,
          isGroup: isGroup,
        ),
      ),
    );

    if (!mounted) return;
    await _refreshConversations();
  }

  @override
  void dispose() {
    _conversationRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Chats',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Friend requests',
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const FriendRequestsScreen(),
                            ),
                          );
                          if (mounted) {
                            setState(() {
                              _friendRequestCount = _loadFriendRequestCount();
                            });
                            _refreshConversations();
                          }
                        },
                        icon: FutureBuilder<int>(
                          future: _friendRequestCount,
                          builder: (context, snapshot) {
                            final count = snapshot.data ?? 0;
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const Icon(Icons.person_add_alt_1_outlined),
                                if (count > 0)
                                  Positioned(
                                    right: -8,
                                    top: -8,
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        minWidth: 16,
                                        minHeight: 16,
                                      ),
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        count > 99 ? '99+' : '$count',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                      Material(
                        color: _green,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SearchUserScreen(),
                            ),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                style: TextStyle(fontSize: 15, color: scheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search',
                  hintStyle: const TextStyle(color: _inkFaint, fontSize: 15),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: _inkFaint,
                    size: 20,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.close,
                            size: 18,
                            color: _inkFaint,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            context.read<SearchUsersBloc>().add(
                              const SearchQueryChanged(''),
                            );
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: scheme.surfaceContainerHigh,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (q) {
                  context.read<SearchUsersBloc>().add(SearchQueryChanged(q));
                  setState(() {}); // refresh suffixIcon visibility
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: BlocBuilder<SearchUsersBloc, SearchUsersState>(
                builder: (context, state) {
                  if (state is SearchUsersInitial) {
                    return FutureBuilder<List<ConversationSummary>>(
                      future: _conversations,
                      initialData: _visibleConversations,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData &&
                            snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError && !snapshot.hasData) {
                          return Center(
                            child: Text(
                              'Could not load conversations: ${snapshot.error}',
                            ),
                          );
                        }
                        final conversations = snapshot.data ?? const [];
                        if (conversations.isEmpty) return const _EmptyState();
                        final now = DateTime.now();
                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          itemCount: conversations.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final conversation = conversations[index];
                            final day = _chatDay(conversation.lastMessageAt);
                            final startsDay =
                                index == 0 ||
                                day !=
                                    _chatDay(
                                      conversations[index - 1].lastMessageAt,
                                    );
                            return Column(
                              key: ValueKey(conversation.id),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (startsDay)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 12,
                                      bottom: 8,
                                    ),
                                    child: Text(
                                      _dayLabel(context, day, now),
                                      style: TextStyle(
                                        color: scheme.onSurfaceVariant,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                Dismissible(
                                  key: ValueKey(conversation.id),
                                  direction: conversation.isGroup
                                      ? DismissDirection.none
                                      : DismissDirection.endToStart,
                                  confirmDismiss: (_) async {
                                    await _removeChat(conversation);
                                    // The refreshed list removes the row.
                                    return false;
                                  },
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    color: Colors.red,
                                    child: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.white,
                                    ),
                                  ),
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: ConversationAvatar(
                                      conversation: conversation,
                                    ),
                                    title: Text(
                                      conversation.participantName,
                                      style: TextStyle(
                                        color: scheme.onSurface,
                                        fontWeight: conversation.isUnread
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      conversation.lastMessage,
                                      style: TextStyle(
                                        fontWeight: conversation.isUnread
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        color: conversation.isMissedCall
                                            ? const Color(0xFFE0433C)
                                            : conversation.isUnread
                                            ? scheme.onSurface
                                            : scheme.onSurfaceVariant,
                                      ),
                                    ),
                                    trailing: Text(
                                      _formatChatTime(
                                        conversation.lastMessageAt,
                                      ),
                                      style: const TextStyle(
                                        color: _inkFaint,
                                        fontSize: 12,
                                      ),
                                    ),
                                    onTap: () => _showConversation(
                                      conversationId: conversation.id,
                                      participantId: conversation.participantId,
                                      participantName:
                                          conversation.participantName,
                                      isGroup: conversation.isGroup,
                                      avatarUrl: conversation.avatarUrl,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  }

                  // Actively searching -> show API results.
                  if (state is SearchUsersLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is SearchUsersError) {
                    return Center(child: Text('Error: ${state.message}'));
                  }
                  if (state is SearchUsersLoaded) {
                    if (state.results.isEmpty) {
                      return const Center(child: Text('No users found'));
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: state.results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => UserSearchTile(
                        key: ValueKey(state.results[i].id),
                        user: state.results[i],
                        onTap: () {
                          final user = state.results[i];
                          _openConversation(
                            FriendContact(
                              id: user.id,
                              name: user.name,
                              email: '',
                            ),
                            avatarUrl: user.avatarUrl,
                          );
                        },
                        onAddFriend: () => sl<FriendRequestRemoteDatasource>()
                            .sendFriendRequest(receiverId: state.results[i].id),
                      ),
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_off_outlined,
                size: 32,
                color: Color(0xFF9AA0A6),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Contacts',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "You haven't connected with anyone yet.\nTap + to search and start a chat.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF9AA0A6),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
