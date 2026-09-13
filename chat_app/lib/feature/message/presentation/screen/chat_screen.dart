import 'dart:async';

import 'package:chat_app/feature/searchusers/presentation/bloc/search_user.state.dart';
import 'package:chat_app/feature/searchusers/presentation/bloc/search_user_bloc.dart';
import 'package:chat_app/feature/searchusers/presentation/bloc/search_user_event.dart';
import 'package:chat_app/feature/searchusers/presentation/widget/user_search_tile.dart';
import 'package:chat_app/core/service/injection_container.dart';
import 'package:chat_app/core/service/token_storage.dart';
import 'package:chat_app/feature/friends/data/datasource/friend_request_remote_datasource.dart';
import 'package:chat_app/feature/message/data/datasource/message_datasource.dart';
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
  final Map<int, String> _lastMessageKeys = {};
  bool _hasConversationSnapshot = false;

  static const _green = Color(0xFF34C471);
  static const _ink = Color(0xFF1B1D21);
  static const _inkFaint = Color(0xFF9AA0A6);
  static const _chipBg = Color(0xFFF1F2F4);

  @override
  void initState() {
    super.initState();
     WidgetsBinding.instance.addObserver(this);
    _friendRequestCount = _loadFriendRequestCount();
    _conversations = _loadConversations();
    _conversationRefreshTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _refreshConversations(),
    );
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

  Future<List<ConversationSummary>> _loadConversations() {
    return sl<MessageDataSource>().getConversations();
  }

  String _messageKey(ConversationSummary conversation) {
    return '${conversation.lastMessageSenderId}|${conversation.lastMessageAt?.toIso8601String()}|${conversation.lastMessage}';
  }

  Future<void> _refreshConversations() async {
    try {
      final conversations = await _loadConversations();
      final currentUserId = await sl<TokenStorage>().getUserId();
      if (!mounted) return;

      final incoming = <ConversationSummary>[];
      for (final conversation in conversations) {
        final key = _messageKey(conversation);
        final previousKey = _lastMessageKeys[conversation.id];
        final isNewIncoming = _hasConversationSnapshot &&
            currentUserId != null &&
            previousKey != null &&
            previousKey != key &&
            conversation.lastMessageSenderId != currentUserId;
        if (isNewIncoming) incoming.add(conversation);
        _lastMessageKeys[conversation.id] = key;
      }
      _hasConversationSnapshot = true;

      setState(() {
        _conversations = Future.value(conversations);
      });

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
    }
  }

  String _formatChatTime(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Future<void> _openConversation(FriendContact friend) async {
    try {
      final conversationId = await sl<OpenDirectConversationUsecase>().call(
        participantId: friend.id,
      );
      if (!mounted) return;
      await _showConversation(
        conversationId: conversationId,
        participantId: friend.id,
        participantName: friend.name,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open chat: $error')));
    }
  }

  Future<bool> _deleteFriend(FriendContact friend) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove friend?'),
        content: Text('Remove ${friend.name} from your contacts?'),
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
    if (confirmed != true || !mounted) return false;

    try {
      await sl<FriendRequestRemoteDatasource>().deleteFriend(
        friendId: friend.id,
      );
      if (!mounted) return false;
      setState(() {
        _conversations = _loadConversations();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${friend.name} was removed.')));
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
      return false;
    }
  }

  Future<void> _showConversation({
    required int conversationId,
    required String participantId,
    required String participantName,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConversationScreen(
          conversationId: conversationId,
          participantId: participantId,
          participantName: participantName,
        ),
      ),
    );

    // The chat screen remains alive beneath the conversation route, so its
    // cached Future must be replaced to show the newest message and timestamp.
    if (!mounted) return;
    setState(() {
      _conversations = _loadConversations();
    });
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Chats',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: _ink,
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
                              _conversations = _loadConversations();
                            });
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
                style: const TextStyle(fontSize: 15, color: _ink),
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
                  fillColor: _chipBg,
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
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Could not load conversations: ${snapshot.error}',
                            ),
                          );
                        }
                        final conversations = snapshot.data ?? const [];
                        if (conversations.isEmpty) return const _EmptyState();
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
                            return Dismissible(
                              key: ValueKey(conversation.id),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (_) => Future.value(false),
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
                                leading: CircleAvatar(
                                  backgroundColor: _green,
                                  child: Text(
                                    conversation.participantName.isEmpty
                                        ? '?'
                                        : conversation.participantName[0]
                                            .toUpperCase(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(
                                  conversation.participantName,
                                  style: const TextStyle(
                                    color: _ink,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(conversation.lastMessage),
                                trailing: Text(
                                  _formatChatTime(conversation.lastMessageAt),
                                  style: const TextStyle(
                                    color: _inkFaint,
                                    fontSize: 12,
                                  ),
                                ),
                                onTap: () => _showConversation(
                                  conversationId: conversation.id,
                                  participantId: conversation.participantId,
                                  participantName: conversation.participantName,
                                ),
                              ),
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
                          // TODO: navigate into a new/existing conversation
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
              decoration: const BoxDecoration(
                color: Color(0xFFF1F2F4),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_off_outlined,
                size: 32,
                color: Color(0xFF9AA0A6),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Contacts',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1B1D21),
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
