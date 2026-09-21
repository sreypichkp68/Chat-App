import 'package:chat_app/core/constants/api_entpoint.dart';
import 'package:flutter/material.dart';

ImageProvider? profileAvatarImage(String? url) {
  if (url == null || url.trim().isEmpty) return null;
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return null;
  final resolved = Uri.parse(ApiEntpoint.url).resolveUri(uri);
  if (resolved.scheme != 'https' && resolved.scheme != 'http') return null;
  return NetworkImage(resolved.toString());
}
