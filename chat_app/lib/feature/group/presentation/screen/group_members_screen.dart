import 'package:get/get.dart';
import 'package:chat_app/core/service/injection_container.dart';
import 'package:chat_app/core/service/token_storage.dart';
import 'package:chat_app/feature/friends/data/datasource/friend_request_remote_datasource.dart';
import 'package:chat_app/feature/group/data/datasource/group_remote_data_source.dart';
import 'package:chat_app/feature/group/data/model/group_model.dart';
import 'package:flutter/material.dart';
import 'package:chat_app/core/widget/profile_avatar_image.dart';

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
  int? _removingId;

  Future<void> _removeMember(int userId, String name) async {
    if (_removingId != null || _adding) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove member?'.tr),
        content: Text(
          'Remove $name from this group? Their account and existing messages will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remove'.tr),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _removingId = userId);
    try {
      await sl<GroupRemoteDataSource>().removeMember(
        groupId: widget.groupId,
        userId: userId,
      );
      if (!mounted) return;
      final group = _group!;
      setState(() {
        _group = GroupModel(
          id: group.id,
          type: group.type,
          title: group.title,
          avatarUrl: group.avatarUrl,
          createdBy: group.createdBy,
          members: group.members
              .where((member) => member.id != userId)
              .toList(),
        );
        _selectedIds.remove(userId);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$name removed from the group.')));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _removingId = null);
    }
  }

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
    if (_adding || _removingId != null || _selectedIds.isEmpty) return;
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Members added to the group'.tr)));
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
      appBar: AppBar(
        title: Text('Group members'.tr),
        actions: [
          IconButton(
            tooltip: 'Refresh profiles'.tr,
            onPressed: _loading || _adding || _removingId != null
                ? null
                : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  TextButton(onPressed: _load, child: Text('Retry'.tr)),
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
                      foregroundImage: profileAvatarImage(member.avatarUrl),
                      onForegroundImageError:
                          profileAvatarImage(member.avatarUrl) == null
                          ? null
                          : (_, error) {},
                      child: Text(
                        member.name.isEmpty
                            ? '?'
                            : member.name[0].toUpperCase(),
                      ),
                    ),
                    title: Text(member.name),
                    trailing: isAdmin && member.id.toString() != _currentUserId
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (member.role == 'admin') Text('Admin'.tr),
                              if (_removingId == member.id)
                                const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              else
                                IconButton(
                                  tooltip: 'Remove ${member.name}',
                                  icon: const Icon(
                                    Icons.person_remove_outlined,
                                  ),
                                  onPressed: _adding || _removingId != null
                                      ? null
                                      : () => _removeMember(
                                          member.id,
                                          member.name,
                                        ),
                                ),
                            ],
                          )
                        : member.role == 'admin'
                        ? Text('Admin'.tr)
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
                    decoration: InputDecoration(
                      hintText: 'Search friends'.tr,
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) =>
                        setState(() => _query = value.trim().toLowerCase()),
                  ),
                  const SizedBox(height: 8),
                  if (availableFriends.isEmpty)
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No friends available to add.'.tr),
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
                  onPressed:
                      _selectedIds.isEmpty || _adding || _removingId != null
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
