import 'package:chat_app/feature/searchusers/domain/entity/user_entity.dart';
import 'package:chat_app/feature/message/presentation/widget/chat_color.dart';
import 'package:flutter/material.dart';

class UserSearchTile extends StatefulWidget {
  final UserEntity user;
  final VoidCallback onTap;
  final Future<void> Function()? onAddFriend;

  const UserSearchTile({
    super.key,
    required this.user,
    required this.onTap,
    this.onAddFriend,
  });

  @override
  State<UserSearchTile> createState() => _UserSearchTileState();
}

class _UserSearchTileState extends State<UserSearchTile> {
  bool _requestSent = false;
  bool _isSending = false;

  Future<void> _sendFriendRequest() async {
    setState(() => _isSending = true);
    try {
      await widget.onAddFriend?.call();
      if (!mounted) return;
      setState(() => _requestSent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Friend request sent to ${widget.user.name}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: widget.onTap,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: ChatColors.mustard,
        backgroundImage: widget.user.avatarUrl != null
            ? NetworkImage(widget.user.avatarUrl!)
            : null,
        child: widget.user.avatarUrl == null
            ? Text(
                widget.user.name.isNotEmpty
                    ? widget.user.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(color: Colors.white),
              )
            : null,
      ),
      title: Text(
        widget.user.name,
        style: ChatType.contactName.copyWith(fontSize: 15, color: scheme.onSurface),
      ),
      subtitle: widget.user.statusMessage != null
          ? Text(widget.user.statusMessage!, style: ChatType.timestamp.copyWith(color: scheme.onSurfaceVariant))
          : null,
      trailing: widget.onAddFriend == null
          ? null
          : SizedBox(
              height: 34,
              child: _requestSent
                  ? OutlinedButton.icon(
                      onPressed: null,
                      icon: Icon(Icons.check, size: 16),
                      label: Text('Sent'),
                    )
                  : FilledButton.icon(
                      onPressed: _isSending ? null : _sendFriendRequest,
                      icon: _isSending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.person_add_alt_1, size: 16),
                      label: Text(_isSending ? 'Sending' : 'Add Friend'),
                    ),
            ),
    );
  }
}
