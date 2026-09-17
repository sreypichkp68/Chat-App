import 'package:chat_app/feature/message/presentation/widget/chat_color.dart';
import 'package:flutter/material.dart';

/// A message bubble with a small folded paper corner instead of a
/// generic speech-bubble tail — sent messages fold bottom-right,
/// received messages fold bottom-left.
class FoldedBubble extends StatelessWidget {
  final String text;
  final String time;
  final bool isMine;

  const FoldedBubble({
    super.key,
    required this.text,
    required this.time,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isMine ? ChatColors.pine : ChatColors.clay;
    final bodyStyle = isMine ? ChatType.bodyOnPine : ChatType.body;
    final timeStyle = isMine ? ChatType.timestampOnPine : ChatType.timestamp;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints: const BoxConstraints(maxWidth: 280),
        child: CustomPaint(
          painter: _FoldPainter(color: bg, isMine: isMine),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(text, style: bodyStyle),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(time, style: timeStyle),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FoldPainter extends CustomPainter {
  final Color color;
  final bool isMine;
  static const double fold = 10;
  static const double radius = 16;

  _FoldPainter({required this.color, required this.isMine});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path();

    if (isMine) {
      path.moveTo(radius, 0);
      path.lineTo(w, 0);
      path.lineTo(w, h - fold);
      path.lineTo(w - fold, h);
      path.lineTo(radius, h);
      path.arcToPoint(
        Offset(0, h - radius),
        radius: const Radius.circular(radius),
      );
      path.lineTo(0, radius);
      path.arcToPoint(Offset(radius, 0), radius: const Radius.circular(radius));
    } else {
      path.moveTo(fold, h);
      path.lineTo(0, h - fold);
      path.lineTo(0, radius);
      path.arcToPoint(Offset(radius, 0), radius: const Radius.circular(radius));
      path.lineTo(w - radius, 0);
      path.arcToPoint(Offset(w, radius), radius: const Radius.circular(radius));
      path.lineTo(w, h - radius);
      path.arcToPoint(
        Offset(w - radius, h),
        radius: const Radius.circular(radius),
      );
      path.close();
    }

    canvas.drawPath(path, Paint()..color = color);

    // the folded corner itself, slightly darkened
    final foldPath = Path();
    final hsl = HSLColor.fromColor(color);
    final darker = hsl
        .withLightness((hsl.lightness - 0.12).clamp(0, 1))
        .toColor();
    if (isMine) {
      foldPath.moveTo(w - fold, h);
      foldPath.lineTo(w, h - fold);
      foldPath.lineTo(w - fold, h - fold);
      foldPath.close();
    } else {
      foldPath.moveTo(0, h - fold);
      foldPath.lineTo(fold, h);
      foldPath.lineTo(fold, h - fold);
      foldPath.close();
    }
    canvas.drawPath(foldPath, Paint()..color = darker);
  }

  @override
  bool shouldRepaint(covariant _FoldPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.isMine != isMine;
}
