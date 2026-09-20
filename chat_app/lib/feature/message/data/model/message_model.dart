import 'package:chat_app/feature/message/domain/entity/message_entity.dart';

class MessageModel extends MessageEntity {
  MessageModel({
    required super.id,
    required super.conversationId,
    required super.senderId,
    super.senderName,
    required super.content,
    required super.messageType,
    super.metadata,
    super.replyToMessageId,
    required super.createdAt,
    required super.updatedAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: _asInt(json['id']),
      conversationId: _asInt(json['conversation_id']),
      senderId: _asInt(json['sender_id']),
      senderName: json['sender'] is Map
          ? (json['sender'] as Map)['name']?.toString()
          : json['sender_name']?.toString(),
      content: json['content'] as String? ?? '',
      messageType: json['message_type'] as String? ?? 'text',
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
      replyToMessageId: json['reply_to_message_id'] == null
          ? null
          : _asInt(json['reply_to_message_id']),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.parse(value.toString());
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'sender_name': senderName,
      'content': content,
      'message_type': messageType,
      'metadata': metadata,
      'reply_to_message_id': replyToMessageId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
