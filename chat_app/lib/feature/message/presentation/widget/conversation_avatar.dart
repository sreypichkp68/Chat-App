import 'package:flutter/material.dart';
import 'package:chat_app/core/widget/profile_avatar_image.dart';
import 'package:chat_app/feature/message/data/datasource/message_datasource.dart';

class ConversationAvatar extends StatelessWidget {
  const ConversationAvatar({super.key, required this.conversation});
  final ConversationSummary conversation;
  @override
  Widget build(BuildContext context) {
    final photo = profileAvatarImage(conversation.avatarUrl);
    final members = conversation.memberAvatars;
    if (conversation.isGroup && photo == null && members.isNotEmpty) {
      return SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          children: [
            for (var i = 0; i < members.length; i++)
              Positioned(
                left: i == 0 ? 0 : null,
                right: i == 1 ? 0 : null,
                top: i == 0 ? 0 : null,
                bottom: i == 1 ? 0 : null,
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFF34C471),
                  foregroundImage: profileAvatarImage(members[i].avatarUrl),
                  onForegroundImageError:
                      profileAvatarImage(members[i].avatarUrl) == null
                      ? null
                      : (_, error) {},
                  child: Text(
                    members[i].name.isEmpty
                        ? '?'
                        : members[i].name[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      );
    }
    return CircleAvatar(
      backgroundColor: const Color(0xFF34C471),
      foregroundImage: photo,
      onForegroundImageError: photo == null ? null : (_, error) {},
      child: conversation.isGroup
          ? const Icon(Icons.group, color: Colors.white)
          : Text(
              conversation.participantName.isEmpty
                  ? '?'
                  : conversation.participantName[0].toUpperCase(),
              style: const TextStyle(color: Colors.white),
            ),
    );
  }
}
