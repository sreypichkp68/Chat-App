import 'package:chat_app/feature/message/presentation/widget/chat_color.dart';
import 'package:flutter/material.dart';

class PulseAvatar extends StatefulWidget {
  final String initials;
  final bool online;
  const PulseAvatar({super.key, required this.initials, this.online = true});

  @override
  State<PulseAvatar> createState() => _PulseAvatarState();
}

class _PulseAvatarState extends State<PulseAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: ChatColors.pine.withValues(alpha: 0.15),
            child: Text(
              widget.initials,
              style: ChatType.body.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          if (widget.online)
            Positioned(
              right: -1,
              bottom: -1,
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 12 + 8 * _ctrl.value,
                        height: 12 + 8 * _ctrl.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ChatColors.mustard.withValues(
                            alpha: (1 - _ctrl.value) * 0.5,
                          ),
                        ),
                      ),
                      Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ChatColors.mustard,
                          border: Border.all(color: ChatColors.paper, width: 2),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
