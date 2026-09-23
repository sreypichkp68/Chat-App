import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';

class LanguageController {
  LanguageController._();

  static const supportedLocales = [Locale('en'), Locale('km'), Locale('zh')];
  static const names = {'en': 'English', 'km': 'ខ្មែរ', 'zh': '中文（简体）'};
  static const _storage = FlutterSecureStorage();
  static const storageKey = 'app_language';
  static final currentLocale = ValueNotifier(const Locale('en'));
  static Locale get locale => currentLocale.value;
  static set locale(Locale value) => currentLocale.value = value;

  static Future<void> initialize() async {
    try {
      final saved = await _storage.read(key: storageKey);
      locale = Locale(names.containsKey(saved) ? saved! : 'en');
    } catch (_) {
      locale = const Locale('en');
    }
  }

  static Future<void> setLocale(Locale next) async {
    if (!names.containsKey(next.languageCode)) return;
    await _storage.write(key: storageKey, value: next.languageCode);
    Get.locale = next;
    locale = next;
  }

  static Future<void> showPicker(BuildContext context) async {
    final selected = await showDialog<Locale>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Language'.tr),
        children: [
          for (final choice in supportedLocales)
            ListTile(
              title: Text(names[choice.languageCode]!),
              trailing: choice == locale ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, choice),
            ),
        ],
      ),
    );
    if (selected == null || selected == locale) return;
    try {
      await setLocale(selected);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save language preference.'.tr)),
      );
    }
  }
}
