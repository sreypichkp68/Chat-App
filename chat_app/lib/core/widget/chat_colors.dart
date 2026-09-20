import 'package:flutter/material.dart';

/// Warm, paper-and-ink palette for the postmark-themed chat UI.
class ChatColors {
  ChatColors._();
  static const Color paper = Color(0xFFF8F2E7); // background
  static const Color ink = Color(0xFF23303D); // primary text
  static const Color inkFaint = Color(0xFF8A93A0); // secondary text
  static const Color clay = Color(0xFFE4D5BE); // soft surface / fill
  static const Color mustard = Color(0xFFE0A72F); // accent / unread badges
  static const Color online = Color(0xFF4CAF6D); // presence dot
}

/// Typography system:
/// - Fraunces (serif) for names — editorial, warm
/// - Inter for body copy — clean and readable
/// - JetBrains Mono for the small uppercase "postmark" labels — stamp-like texture
class ChatType {
  ChatType._();

  static const TextStyle contactName = TextStyle(
    fontFamily: 'Fraunces',
    fontWeight: FontWeight.w600,
    fontSize: 18,
    color: ChatColors.ink,
    height: 1.2,
  );

  static const TextStyle body = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w500,
    fontSize: 15,
    color: ChatColors.ink,
    height: 1.3,
  );

  static const TextStyle timestamp = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w500,
    fontSize: 12,
    color: ChatColors.inkFaint,
    height: 1.2,
  );

  static const TextStyle postmark = TextStyle(
    fontFamily: 'JetBrainsMono',
    fontWeight: FontWeight.w600,
    fontSize: 11,
    letterSpacing: 1.4,
    color: ChatColors.inkFaint,
    height: 1.2,
  );
}
