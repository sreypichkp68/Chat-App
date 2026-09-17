import 'package:chat_app/feature/message/presentation/widget/chat_color.dart';
import 'package:flutter/material.dart';

class PostmarkDivider extends StatelessWidget {
  final String label;
  const PostmarkDivider({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: ChatColors.inkFaint.withValues(alpha: 0.35),
              width: 1,
              style: BorderStyle.solid,
            ),
          ),
          child: Text('· ${label.toUpperCase()} ·', style: ChatType.postmark),
        ),
      ),
    );
  }
}
