import 'dart:async';

import 'package:chat_app/core/service/injection_container.dart';
import 'package:chat_app/feature/group/presentation/bloc/group_bloc.dart';
import 'package:chat_app/feature/group/presentation/screen/adduser_group.dart';
import 'package:chat_app/feature/message/data/datasource/message_datasource.dart';
import 'package:chat_app/feature/message/presentation/screen/conversation_screen.dart';
import 'package:chat_app/feature/searchusers/presentation/bloc/search_user_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> with WidgetsBindingObserver {
  List<ConversationSummary> _groups = const [];
  Timer? _refreshTimer;
  bool _loading = true;
  bool _refreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) _refresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final conversations = await sl<MessageDataSource>().getConversations();
      final groups = conversations.where((item) => item.isGroup).toList()
        ..sort((a, b) {
          final aTime =
              a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime =
              b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _createGroup() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => sl<SearchUsersBloc>()),
            BlocProvider(create: (_) => sl<GroupBloc>()),
          ],
          child: const AdduserGroup(),
        ),
      ),
    );
    if (mounted) await _refresh();
  }

  Future<void> _openGroup(ConversationSummary group) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConversationScreen(
          conversationId: group.id,
          participantId: group.participantId,
          participantName: group.participantName,
          isGroup: true,
        ),
      ),
    );
    if (mounted) await _refresh();
  }

  String _formatTime(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).scaffoldBackgroundColor;
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        surfaceTintColor: background,
        title: const Text('Groups'),
        actions: [
          IconButton(
            tooltip: 'Create group',
            onPressed: _createGroup,
            icon: const Icon(Icons.group_add_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _groups.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load groups'),
                  TextButton(onPressed: _refresh, child: const Text('Retry')),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _refresh,
              child: _groups.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 180),
                        Center(child: Text('No groups yet')),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: _groups.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final group = _groups[index];
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFF34C471),
                            child: Icon(Icons.group, color: Colors.white),
                          ),
                          title: Text(
                            group.participantName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            group.lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: group.isMissedCall
                                ? const TextStyle(color: Color(0xFFE0433C))
                                : null,
                          ),
                          trailing: Text(
                            _formatTime(group.lastMessageAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                          onTap: () => _openGroup(group),
                        );
                      },
                    ),
            ),
    );
  }
}
