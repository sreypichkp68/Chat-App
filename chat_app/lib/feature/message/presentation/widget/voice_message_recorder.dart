import 'dart:async';
import 'dart:io';

import 'package:chat_app/feature/message/domain/entity/message_entity.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'voice_message_player.dart';

/// Keeps the recording until a successful send, so a failed upload can be retried.
class VoiceMessageRecorder extends StatefulWidget {
  const VoiceMessageRecorder({
    super.key,
    required this.send,
    required this.canRecord,
  });
  final Future<MessageEntity> Function(File file, int seconds) send;
  final bool Function() canRecord;

  @override
  State<VoiceMessageRecorder> createState() => _VoiceMessageRecorderState();
}

class _VoiceMessageRecorderState extends State<VoiceMessageRecorder>
    with WidgetsBindingObserver {
  final _recorder = AudioRecorder();
  final _watch = Stopwatch();
  Timer? _timer;
  Directory? _directory;
  File? _file;
  bool _recording = false;
  bool _busy = false;
  bool _sending = false;
  String? _error;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _start() async {
    if (_busy || _recording) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!widget.canRecord()) {
        throw StateError('Finish the current call first.'.tr);
      }
      if (!await _recorder.hasPermission()) {
        throw StateError(
          'Allow microphone access in Settings to record a voice message.'.tr,
        );
      }
      if (!mounted ||
          !widget.canRecord() ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return;
      }
      await VoiceMessagePlayer.pauseActive();
      _directory ??= await (await getTemporaryDirectory()).createTemp(
        'voice_message_',
      );
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: '${_directory!.path}/voice.m4a',
      );
      _watch
        ..reset()
        ..start();
      if (!mounted) return;
      setState(() {
        _recording = true;
        _seconds = 0;
      });
      _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (!mounted) return;
        setState(() => _seconds = _watch.elapsed.inSeconds);
        if (_seconds >= 300 ||
            !widget.canRecord() ||
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed) {
          unawaited(_stop());
        }
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is StateError
              ? error.message.toString()
              : 'Could not record voice message.'.tr,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    if (!_recording || _busy) return;
    setState(() => _busy = true);
    _timer?.cancel();
    _watch.stop();
    try {
      final path = await _recorder.stop();
      if (path == null || _watch.elapsedMilliseconds < 1000) {
        throw StateError('Record at least one second.'.tr);
      }
      final file = File(path);
      if (!await file.exists() || await file.length() == 0) {
        throw StateError('Could not record voice message.'.tr);
      }
      if (mounted) {
        setState(() {
          _file = file;
          _seconds = (_watch.elapsedMilliseconds / 1000).ceil().clamp(1, 300);
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is StateError
              ? error.message.toString()
              : 'Could not record voice message.'.tr,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _recording = false;
          _busy = false;
        });
      }
    }
  }

  Future<void> _send() async {
    if (_file == null || _busy) return;

    setState(() {
      _busy = true;
      _sending = true;
      _error = null;
    });

    try {
      final message = await widget.send(_file!, _seconds);

      debugPrint('====== VOICE MESSAGE ======');
      debugPrint('TYPE: ${message.messageType}');
      debugPrint('AUDIO URL: ${message.audioUrl}');
      debugPrint('CONTENT: ${message.content}');
      debugPrint('METADATA: ${message.metadata}');
      debugPrint('IS AUDIO: ${message.isAudio}');
      debugPrint('===========================');

      if (!mounted) return;

      Navigator.of(context).pop(message);
    } catch (error, stack) {
      debugPrint('VOICE SEND ERROR: $error');
      debugPrint('$stack');

      if (mounted) {
        setState(() {
          _error = 'Could not send voice message. Tap Send to retry.'.tr;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _sending = false;
        });
      }
    }
  }

  Future<void> _cancel() async {
    if (_busy) return;
    setState(() => _busy = true);
    _timer?.cancel();
    try {
      if (_recording) await _recorder.cancel();
    } catch (error) {
      debugPrint('Could not cancel recording: $error');
    } finally {
      if (mounted) {
        setState(() {
          _recording = false;
          _busy = false;
        });
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _recording) unawaited(_stop());
  }

  Future<void> _cleanup() async {
    await _recorder.dispose();
    final directory = _directory;
    if (directory != null && await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    unawaited(
      _cleanup().catchError((Object error) {
        debugPrint('Voice recording cleanup failed: $error');
      }),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy && !_recording,
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Voice message'.tr,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (_recording) ...[
              const Icon(Icons.mic, color: Colors.red, size: 36),
              Text(
                '${'Recording'.tr} ${voiceTime(Duration(seconds: _seconds))}',
              ),
            ] else if (_file != null && !_sending)
              VoiceMessagePlayer(
                source: _file!.path,
                local: true,
                durationSeconds: _seconds,
              )
            else if (!_sending)
              Text('Tap Record to start. Maximum 5 minutes.'.tr),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(12),
                child: LinearProgressIndicator(),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _busy ? null : _cancel,
                  child: Text('Cancel'.tr),
                ),
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : _recording
                      ? _stop
                      : _file == null
                      ? _start
                      : _send,
                  icon: Icon(
                    _recording
                        ? Icons.stop
                        : _file == null
                        ? Icons.mic
                        : Icons.send,
                  ),
                  label: Text(
                    (_sending
                            ? 'Sending voice message...'
                            : _recording
                            ? 'Stop recording'
                            : _file == null
                            ? 'Record'
                            : 'Send')
                        .tr,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
