import 'package:chat_app/core/localization/app_translations.dart';
import 'package:chat_app/core/localization/language_controller.dart';
import 'package:chat_app/core/service/injection_container.dart';
import 'package:chat_app/core/service/token_storage.dart';
import 'package:chat_app/feature/profile/presentation/screen/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late Map<String, String> saved;
  var failWrites = false;

  setUp(() {
    saved = {};
    failWrites = false;
    LanguageController.locale = const Locale('en');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final args = Map<String, dynamic>.from(call.arguments as Map);
          if (call.method == 'read') return saved[args['key']];
          if (call.method == 'write') {
            if (failWrites) throw PlatformException(code: 'storage_failure');
            saved[args['key'] as String] = args['value'] as String;
          }
          return null;
        });
    sl.registerSingleton<TokenStorage>(TokenStorage());
    sl.registerSingleton<http.Client>(
      MockClient((_) async => http.Response('{}', 200)),
    );
  });

  tearDown(() async {
    Get.reset();
    await sl.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Widget app() => ValueListenableBuilder<Locale>(
    valueListenable: LanguageController.currentLocale,
    builder: (context, locale, _) => GetMaterialApp(
      translations: AppTranslations(),
      locale: locale,
      fallbackLocale: const Locale('en'),
      supportedLocales: LanguageController.supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const SettingsScreen(),
    ),
  );

  testWidgets(
    'settings switches all three languages and restores saved choice',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      for (final code in ['km', 'zh', 'en']) {
        final current = LanguageController.locale.languageCode;
        await tester.tap(
          find.text(AppTranslations().keys[current]!['Language']!),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(LanguageController.names[code]!).last);
        await tester.pumpAndSettle();
        expect(
          find.text(AppTranslations().keys[code]!['Profile']!),
          findsOneWidget,
        );
        expect(saved[LanguageController.storageKey], code);
        expect(tester.takeException(), isNull);
        LanguageController.locale = const Locale('xx');
        await LanguageController.initialize();
        expect(LanguageController.locale, Locale(code));
      }
    },
  );

  testWidgets('failed save keeps current language and reports failure', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    failWrites = true;
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(LanguageController.names['km']!));
    await tester.pumpAndSettle();
    expect(LanguageController.locale, const Locale('en'));
    expect(find.text('Could not save language preference.'), findsOneWidget);
  });

  test('unsupported saved language defaults to English', () async {
    saved[LanguageController.storageKey] = 'xx';
    await LanguageController.initialize();
    expect(LanguageController.locale, const Locale('en'));
  });
}
