import 'package:chat_app/core/service/injection_container.dart';
import 'package:chat_app/feature/friends/data/datasource/friend_request_remote_datasource.dart';
import 'package:chat_app/feature/message/domain/usecase/open_direct_conversation_usecase.dart';
import 'package:chat_app/feature/message/presentation/screen/conversation_screen.dart';
import 'package:flutter/material.dart';

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  late Future<List<IncomingFriendRequest>> _requests;

  @override
  void initState() {
    super.initState();
    _requests = _loadRequests();
  }

  Future<List<IncomingFriendRequest>> _loadRequests() {
    return sl<FriendRequestRemoteDatasource>().getIncomingRequests();
  }

  Future<void> _respond(IncomingFriendRequest request, String status) async {
    try {
      await sl<FriendRequestRemoteDatasource>().updateRequest(
        requestId: request.id,
        status: status,
      );
      if (!mounted) return;
      setState(() {
        _requests = _loadRequests();
      });
      if (status != 'accepted') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request declined')),
        );
        return;
      }

      final conversationId = await sl<OpenDirectConversationUsecase>().call(
        participantId: request.senderId,
      );
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ConversationScreen(
          conversationId: conversationId,
          participantId: request.senderId,
          participantName: request.senderName,
        ),
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Friend Requests')),
      body: FutureBuilder<List<IncomingFriendRequest>>(
        future: _requests,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Could not load requests: ${snapshot.error}'));
          }
          final requests = snapshot.data ?? const [];
          if (requests.isEmpty) {
            return const Center(child: Text('No pending friend requests'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final request = requests[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(
                    request.senderName.isEmpty
                        ? '?'
                        : request.senderName[0].toUpperCase(),
                  ),
                ),
                title: Text(request.senderName),
                subtitle: Text(request.senderEmail),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Decline',
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => _respond(request, 'declined'),
                    ),
                    IconButton(
                      tooltip: 'Accept',
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () => _respond(request, 'accepted'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
