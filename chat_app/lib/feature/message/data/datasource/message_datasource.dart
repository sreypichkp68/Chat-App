import 'dart:convert';
import 'dart:io';
import 'package:chat_app/core/constants/api_entpoint.dart';
import 'package:chat_app/core/service/token_storage.dart';
import 'package:chat_app/feature/message/data/model/message_model.dart';
import 'package:http/http.dart' as http;

abstract class MessageDataSource {
  Future<List<ConversationSummary>> getConversations();
  Future<void> removeConversation({required int conversationId});

  /// Returns the existing direct conversation with [participantId], or creates it.
  Future<int> openDirectConversation({required String participantId});
  Future<List<MessageModel>> getMessages({required int conversationId});
  Future<MessageModel> sendMessage({
    required int conversationId,
    required String content,
    String messageType,
    int? replyToMessageId,
    Map<String, dynamic>? metadata,
  });
  Future<String> uploadImage(File imageFile);
}

class ConversationSummary {
  final int id;
  final String participantId;
  final String participantName;
  final bool isGroup;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId;
  final bool isMissedCall;

  const ConversationSummary({
    required this.id,
    required this.participantId,
    required this.participantName,
    required this.isGroup,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.lastMessageSenderId,
    required this.isMissedCall,
  });

  factory ConversationSummary.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    final isGroup = json['type'] == 'group';
    // Laravel APIs often call the other user `other_user`, `receiver`, or
    // `contact` instead of `participant`. Accept all of these response shapes.
    final directParticipant = _firstMap(json, const [
      'participant',
      'user',
      'other_user',
      'otherUser',
      'receiver',
      'recipient',
      'contact',
    ]);
    // The Laravel response contains conversation members. For a direct chat,
    // show the member whose ID is not the logged-in user's ID.
    final participant = directParticipant.isNotEmpty
        ? directParticipant
        : _participantFromMembers(json['members'], currentUserId);
    final lastMessage =
        json['last_message'] as Map<String, dynamic>? ?? const {};
    final createdAt = lastMessage['created_at'];
    final lastMessageType = lastMessage['message_type'] as String?;
    final lastMessageContent = lastMessage['content'] as String?;

    String previewText;
    var isMissedCall = false;
    if (lastMessageType == 'image') {
      previewText = '📷 Photo';
    } else if (lastMessageType == 'audio') {
      previewText = '🎤 Voice message';
    } else if (lastMessageType == 'file') {
      previewText = '📎 File';
    } else if (lastMessageType == 'call_log') {
      Map<String, dynamic> meta = {};
      final rawMeta = lastMessage['metadata'];
      if (rawMeta is String) {
        try {
          meta = jsonDecode(rawMeta) as Map<String, dynamic>;
        } catch (_) {}
      } else if (rawMeta is Map) {
        meta = Map<String, dynamic>.from(rawMeta);
      }
      final status = meta['status'] as String?;
      isMissedCall = status == 'missed' || status == 'declined';
      final duration = meta['duration_seconds'] as int?;
      if (meta['group_id'] != null) {
        previewText = status == 'missed' || status == 'declined'
            ? 'Missed group call'
            : duration != null && duration > 0
            ? 'Group call · ${duration ~/ 60}:${(duration % 60).toString().padLeft(2, '0')}'
            : 'Group call ended';
      } else if (status == 'missed' || status == 'declined') {
        previewText = 'Missed call';
      } else if (status == 'no_answer') {
        previewText = 'No answer';
      } else if (duration != null && duration > 0) {
        previewText =
            'Call · ${duration ~/ 60}:${(duration % 60).toString().padLeft(2, '0')}';
      } else {
        previewText = 'Call';
      }
    } else if (lastMessageContent != null && lastMessageContent.isNotEmpty) {
      previewText = lastMessageContent;
    } else {
      previewText = 'Start a conversation';
    }

    final name =
        participant['name'] as String? ??
        participant['username'] as String? ??
        participant['full_name'] as String? ??
        json['participant_name'] as String? ??
        json['other_user_name'] as String? ??
        json['receiver_name'] as String? ??
        json['user_name'] as String? ??
        _combineFirstLast(participant);

    return ConversationSummary(
      id: int.parse(json['id'].toString()),
      participantId: isGroup
          ? json['id'].toString()
          : participant['id'].toString(),
      participantName: isGroup
          ? (json['title']?.toString() ?? 'Group')
          : (name != null && name.isNotEmpty)
          ? name
          : 'Unknown user',
      isGroup: isGroup,
      lastMessage: previewText,
      lastMessageAt: createdAt is String ? DateTime.tryParse(createdAt) : null,
      lastMessageSenderId: lastMessage['sender_id']?.toString(),
      isMissedCall: isMissedCall,
    );
  }

  static String? _combineFirstLast(Map<String, dynamic> participant) {
    final first = participant['first_name'] as String?;
    final last = participant['last_name'] as String?;
    if (first == null && last == null) return null;
    return [first, last].where((s) => s != null && s.isNotEmpty).join(' ');
  }

  static Map<String, dynamic> _firstMap(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    return const {};
  }

  static Map<String, dynamic> _participantFromMembers(
    dynamic members,
    String? currentUserId,
  ) {
    if (members is! List) return const {};

    Map<String, dynamic>? fallback;
    for (final memberValue in members) {
      if (memberValue is! Map) continue;
      final member = Map<String, dynamic>.from(memberValue);
      final userValue = member['user'];
      if (userValue is! Map) continue;
      final user = Map<String, dynamic>.from(userValue);
      fallback ??= user;
      final memberUserId = (member['user_id'] ?? user['id'])?.toString();
      if (currentUserId != null && memberUserId != currentUserId) return user;
    }
    return fallback ?? const {};
  }
}

class MessageDataSourceImpl implements MessageDataSource {
  final http.Client client;
  final TokenStorage tokenStorage;

  MessageDataSourceImpl({required this.client, required this.tokenStorage});

  Future<Map<String, String>> _headers({bool json = false}) async {
    final token = await tokenStorage.getToken();
    return {
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  @override
  Future<void> removeConversation({required int conversationId}) async {
    final response = await client.delete(
      Uri.parse('${ApiEntpoint.conversations}/$conversationId'),
      headers: await _headers(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Could not remove chat: ${response.body}');
    }
  }

  @override
  Future<List<ConversationSummary>> getConversations() async {
    final response = await client.get(
      Uri.parse(ApiEntpoint.conversations),
      headers: await _headers(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Could not load conversations: ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    final currentUserId = await tokenStorage.getUserId();
    final conversations = decoded is List<dynamic>
        ? decoded
        : decoded is Map<String, dynamic>
        ? decoded['data'] as List<dynamic>? ?? const []
        : const <dynamic>[];
    return conversations
        .map(
          (item) => ConversationSummary.fromJson(
            item as Map<String, dynamic>,
            currentUserId: currentUserId,
          ),
        )
        .toList();
  }

  @override
  Future<int> openDirectConversation({required String participantId}) async {
    final response = await client.post(
      Uri.parse(ApiEntpoint.conversations),
      headers: await _headers(json: true),
      body: jsonEncode({'receiver_id': participantId}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Could not open conversation: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] is Map<String, dynamic>
        ? decoded['data'] as Map<String, dynamic>
        : decoded;
    final conversation = data['conversation'] is Map<String, dynamic>
        ? data['conversation'] as Map<String, dynamic>
        : data;
    final id =
        conversation['id'] ??
        conversation['conversation_id'] ??
        data['conversation_id'] ??
        decoded['conversation_id'];
    if (id == null) {
      throw Exception('The server did not return a conversation id.');
    }
    return int.parse(id.toString());
  }

  @override
  Future<List<MessageModel>> getMessages({required int conversationId}) async {
    final response = await client.get(
      Uri.parse('${ApiEntpoint.conversations}/$conversationId/messages'),
      headers: await _headers(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load messages: ${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'];
    final list = data is List<dynamic>
        ? data
        : data is Map<String, dynamic>
        ? data['messages'] as List<dynamic>? ?? const []
        : const <dynamic>[];
    return list.map(_messageFromResponseItem).toList();
  }

  @override
  Future<MessageModel> sendMessage({
    required int conversationId,
    required String content,
    String messageType = 'text',
    int? replyToMessageId,
    Map<String, dynamic>? metadata,
  }) async {
    final response = await client.post(
      Uri.parse('${ApiEntpoint.conversations}/$conversationId/messages'),
      headers: await _headers(json: true),
      body: jsonEncode({
        'content': content,
        'message_type': messageType,
        if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
        if (metadata != null) 'metadata': metadata,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to send message: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'];
    return _messageFromResponseItem(
      data is Map<String, dynamic> ? data : decoded,
    );
  }

  @override
  Future<String> uploadImage(File imageFile) async {
    // NOTE: ApiEntpoint.uploadMessageImage is a placeholder — replace with
    // your real upload endpoint (see the note below the code).
    final uri = Uri.parse(ApiEntpoint.uploadMessageImage);
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _headers());
    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    final streamedResponse = await client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to upload image: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] is Map<String, dynamic>
        ? decoded['data'] as Map<String, dynamic>
        : decoded;

    final url = data['url'] ?? data['image_url'] ?? data['path'];
    if (url == null) {
      throw Exception('Upload succeeded but no URL was returned.');
    }
    return url.toString();
  }

  MessageModel _messageFromResponseItem(dynamic item) {
    final decoded = item is String ? jsonDecode(item) : item;
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'The server returned an invalid message item.',
      );
    }
    return MessageModel.fromJson(decoded);
  }
}
