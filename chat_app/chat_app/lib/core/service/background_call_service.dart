import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Keeps the existing Reverb listener alive while Android is in the background.
class BackgroundCallService {
  static const _channel = MethodChannel('chat_app/background_calls');

  static Future<void> start() => _invoke('start');
  static Future<void> stop() => _invoke('stop');

  static Future<void> _invoke(String method) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>(method);
    } on PlatformException catch (error) {
      debugPrint('Background calls $method failed: $error');
    } on MissingPluginException {
      debugPrint('Background calls are unavailable on this platform.');
    }
  }
}
