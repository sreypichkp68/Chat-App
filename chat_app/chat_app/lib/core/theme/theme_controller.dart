import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ThemeController {
  ThemeController._();

  static const _storage = FlutterSecureStorage();
  static const _storageKey = 'app_theme_mode';
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.light);

  static Future<void> initialize() async {
    try {
      final saved = await _storage.read(key: _storageKey);
      mode.value = saved == 'dark' ? ThemeMode.dark : ThemeMode.light;
    } catch (_) {
      mode.value = ThemeMode.light;
    }
  }

  static Future<void> setMode(ThemeMode next) async {
    await _storage.write(
      key: _storageKey,
      value: next == ThemeMode.dark ? 'dark' : 'light',
    );
    mode.value = next;
  }
}
