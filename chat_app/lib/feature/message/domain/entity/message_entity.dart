class MessageEntity {
  final int id;
  final int conversationId;
  final int senderId;
  final String content;
  final String messageType;
  final Map<String, dynamic>? metadata;
  final int? replyToMessageId;
  final DateTime createdAt;
  final DateTime updatedAt;

  MessageEntity({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.messageType,
    this.metadata,
    this.replyToMessageId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isImage => messageType == 'image';
  String? get imageUrl => metadata?['imageUrl'] as String?;
  String? get localImagePath => metadata?['localPath'] as String?;

  // --- call log ---
 bool get isCallLog => messageType == 'call_log';
  String? get callStatus => metadata?['status'] as String?;
  String? get callType => metadata?['call_type'] as String?;
  int? get callDurationSeconds {
    final raw = metadata?['duration_seconds'];
    if (raw == null) return null;
    return raw is int ? raw : int.tryParse(raw.toString());
  }
}
