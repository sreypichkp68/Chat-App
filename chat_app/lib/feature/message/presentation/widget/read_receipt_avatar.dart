import 'package:chat_app/core/widget/profile_avatar_image.dart';
import 'package:chat_app/feature/message/domain/entity/message_entity.dart';
import 'package:flutter/material.dart';

int? latestSeenMessageId(
  List<MessageEntity> messages,
  String recipientId,
  int lastReadMessageId,
) {
  int? latest;
  for (final message in messages) {
    if (message.id > 0 &&
        message.id <= lastReadMessageId &&
        message.senderId.toString() != recipientId &&
        (message.messageType == 'text' || message.messageType == 'image') &&
        message.metadata?['is_unsent'] != true &&
        (latest == null || message.id > latest)) {
      latest = message.id;
    }
  }
  return latest;
}

class ReadReceiptAvatar extends StatelessWidget {
  const ReadReceiptAvatar({super.key, required this.name, this.avatarUrl});

  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final photo = profileAvatarImage(avatarUrl);
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Tooltip(
          message: 'Seen by $name',
          excludeFromSemantics: true,
          child: Semantics(
            label: 'Seen by $name',
            excludeSemantics: true,
            child: CircleAvatar(
              radius: 9,
              backgroundColor: const Color(0xFF34C471),
              foregroundImage: photo,
              onForegroundImageError: photo == null ? null : (_, error) {},
              child: Text(
                name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
