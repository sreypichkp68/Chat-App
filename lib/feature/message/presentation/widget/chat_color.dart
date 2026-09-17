import 'package:flutter/material.dart';

class ChatColors {
  static const paper = Color(0xFFF6F3EC);
  static const ink = Color(0xFF23303D);
  static const inkFaint = Color(0xFF6B7684);
  static const pine = Color(0xFF2F6F62);
  static const clay = Color(0xFFDCD5C6);
  static const mustard = Color(0xFFE3A72E);
   static const Color online = Color(0xFF4CAF6D);
}

class ChatType {
  static const contactName = TextStyle(
    fontFamily: 'Fraunces',
    fontSize: 19,
    fontWeight: FontWeight.w600,
    color: ChatColors.ink,
  );
  static const body = TextStyle(
    fontFamily: 'Inter',
    fontSize: 15,
    height: 1.35,
    color: ChatColors.ink,
  );
  static const bodyOnPine = TextStyle(
    fontFamily: 'Inter',
    fontSize: 15,
    height: 1.35,
    color: ChatColors.paper,
  );
  static const timestamp = TextStyle(
    fontFamily: 'JetBrainsMono',
    fontSize: 10.5,
    color: ChatColors.inkFaint,
    letterSpacing: 0.2,
  );
  static const timestampOnPine = TextStyle(
    fontFamily: 'JetBrainsMono',
    fontSize: 10.5,
    color: Color(0xBFF6F3EC), // paper at ~75% alpha
    letterSpacing: 0.2,
  );
  static const postmark = TextStyle(
    fontFamily: 'JetBrainsMono',
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    color: ChatColors.inkFaint,
    letterSpacing: 1.2,
  );
}
