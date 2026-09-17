import 'package:chat_app/core/service/injection_container.dart';
import 'package:chat_app/core/service/token_storage.dart';
import 'package:chat_app/feature/friends/data/datasource/friend_request_remote_datasource.dart';
import 'package:chat_app/feature/group/data/datasource/group_remote_data_source.dart';
import 'package:chat_app/feature/group/data/model/group_model.dart';
import 'package:flutter/material.dart';

class GroupMembersScreen extends StatefulWidget {
  final int groupId;

  const GroupMembersScreen({super.key, required this.groupId});

  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  GroupModel? _group;
  List<FriendContact> _friends = const [];
  String? _currentUserId;
  String? _error;
  String _query = '';
  final Set<int> _selectedIds = {};
  bool _loading = true;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        sl<GroupRemoteDataSource>().getGroup(widget.groupId),
        sl<FriendRequestRemoteDatasource>().getFriends(),
        sl<TokenStorage>().getUserId(),
      ]);
      if (!mounted) return;
      setState(() {
        _group = results[0] as GroupModel;
        _friends = results[1] as List<FriendContact>;
        _currentUserId = results[2] as String?;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _addMembers() async {
    if (_adding || _selectedIds.isEmpty) return;
    setState(() => _adding = true);
    try {
      final group = await sl<GroupRemoteDataSource>().addMembers(
        groupId: widget.groupId,
        memberIds: _selectedIds.toList(),
      );
      if (!mounted) return;
      setState(() {
        _group = group;
        _selectedIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Members added to the group')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    final isAdmin =
        group?.members.any(
          (member) =>
              member.id.toString() == _currentUserId && member.role == 'admin',
        ) ??
        false;
    final memberIds =
        group?.members.map((member) => member.id).toSet() ?? <int>{};
    final availableFriends = _friends.where((friend) {
      final id = int.tryParse(friend.id);
      return id != null &&
          !memberIds.contains(id) &&
          (friend.name.toLowerCase().contains(_query) ||
              friend.email.toLowerCase().contains(_query));
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Group members')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Text(
                  '${group!.title} · ${group.members.length} members',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ...group.members.map(
                  (member) => ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        member.name.isEmpty
                            ? '?'
                            : member.name[0].toUpperCase(),
                      ),
                    ),
                    title: Text(member.name),
                    trailing: member.role == 'admin'
                        ? const Text('Admin')
                        : null,
                  ),
                ),
                if (isAdmin) ...[
                  const Divider(height: 32),
                  Text(
                    'Add friends',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search friends',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) =>
                        setState(() => _query = value.trim().toLowerCase()),
                  ),
                  const SizedBox(height: 8),
                  if (availableFriends.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No friends available to add.'),
                    ),
                  ...availableFriends.map((friend) {
                    final id = int.parse(friend.id);
                    return CheckboxListTile(
                      value: _selectedIds.contains(id),
                      title: Text(friend.name),
                      subtitle: friend.email.isEmpty
                          ? null
                          : Text(friend.email),
                      onChanged: _adding
                          ? null
                          : (selected) => setState(() {
                              if (selected == true) {
                                _selectedIds.add(id);
                              } else {
                                _selectedIds.remove(id);
                              }
                            }),
                    );
                  }),
                ],
              ],
            ),
      bottomNavigationBar: isAdmin && !_loading && _error == null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: _selectedIds.isEmpty || _adding
                      ? null
                      : _addMembers,
                  child: Text(
                    _adding
                        ? 'Adding...'
                        : 'Add ${_selectedIds.length} member${_selectedIds.length == 1 ? '' : 's'}',
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
