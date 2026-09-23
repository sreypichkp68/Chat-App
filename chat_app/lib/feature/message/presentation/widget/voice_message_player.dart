import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:chat_app/core/constants/api_entpoint.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

String voiceTime(Duration duration) =>
    '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

class VoiceMessagePlayer extends StatefulWidget {
  static Future<void> pauseActive() async {
    await _VoiceMessagePlayerState._active?._pause();
  }

  const VoiceMessagePlayer({
    super.key,
    required this.source,
    this.local = false,
    this.durationSeconds = 0,
    this.color,
  });
  final String source;
  final bool local;
  final int durationSeconds;
  final Color? color;

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer>
    with WidgetsBindingObserver {
  static _VoiceMessagePlayerState? _active;
  AudioPlayer? _player;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _playing = false;
  bool _busy = false;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _pause() async {
    try {
      await _player?.pause();
    } catch (error) {
      debugPrint('Could not pause voice message: $error');
    }
    if (mounted) setState(() => _playing = false);
  }

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_playing) {
        await _pause();
      } else {
        if (_active != this) await _active?._pause();
        if (!mounted) return;
        _active = this;
        if (_player == null) {
          final player = _player = AudioPlayer();
          _subscriptions.add(
            player.onPositionChanged.listen((position) {
              if (mounted) setState(() => _position = position);
            }),
          );
          _subscriptions.add(
            player.onPlayerComplete.listen((_) {
              if (mounted) {
                setState(() {
                  _playing = false;
                  _position = Duration.zero;
                });
              }
            }),
          );
        }
        final source = widget.local
            ? DeviceFileSource(widget.source)
            : UrlSource(
                Uri.parse(ApiEntpoint.url).resolve(widget.source).toString(),
              );
        await _player!.play(source, position: _position);
        if (!mounted) return;
        if (_active == this && WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed &&
            ModalRoute.of(context)?.isCurrent == true) {
          setState(() => _playing = true);
        } else {
          await _pause();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _playing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not play voice message.'.tr)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_pause());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_active == this) _active = null;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_player?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: (_playing ? 'Pause voice message' : 'Play voice message').tr,
        onPressed: _busy ? null : _toggle,
        color: widget.color,
        icon: _busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
      ),
      Icon(Icons.graphic_eq, color: widget.color),
      const SizedBox(width: 8),
      Text(
        voiceTime(
          _position == Duration.zero
              ? Duration(seconds: widget.durationSeconds)
              : _position,
        ),
        style: TextStyle(color: widget.color),
      ),
    ],
  );
}
