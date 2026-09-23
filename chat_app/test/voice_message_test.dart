import 'dart:convert';
import 'dart:io';

import 'package:chat_app/core/service/token_storage.dart';
import 'package:chat_app/feature/message/data/datasource/message_datasource.dart';
import 'package:chat_app/feature/message/data/model/message_model.dart';
import 'package:chat_app/feature/message/presentation/widget/read_receipt_avatar.dart';
import 'package:chat_app/feature/message/presentation/widget/voice_message_player.dart';
import 'package:chat_app/feature/message/presentation/widget/voice_message_recorder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Storage extends TokenStorage {
  @override
  Future<String?> getToken() async => 'voice-test-token';
}

Map<String, dynamic> audioMessage() => {
  'id': 12,
  'conversation_id': 7,
  'sender_id': 1,
  'content': null,
  'message_type': 'audio',
  'metadata': {
    'audio_url': 'https://example.com/voice.m4a',
    'duration_seconds': 4,
  },
  'created_at': '2026-09-23T10:00:00Z',
  'updated_at': '2026-09-23T10:00:00Z',
};

void main() {
  for (final inCall in [false, true]) {
    testWidgets(
      inCall
          ? 'cannot record during a call'
          : 'denied microphone does not record or send',
      (tester) async {
        const channel = MethodChannel('com.llfbandit.record/messages');
        final methods = <String>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async {
            methods.add(call.method);
            if (call.method == 'hasPermission') return false;
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VoiceMessageRecorder(
                canRecord: () => !inCall,
                send: (_, _) async => throw StateError('Must not send'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Record'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            inCall
                ? 'Finish the current call first.'
                : 'Allow microphone access in Settings to record a voice message.',
          ),
          findsOneWidget,
        );
        expect(methods, isNot(contains('start')));
        expect(find.text('Send'), findsNothing);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
  test(
    'voice message uploads authenticated multipart audio with duration',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'voice_upload_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = await File(
        '${directory.path}/voice.m4a',
      ).writeAsBytes([1, 2, 3]);
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/conversations/7/messages');
        expect(request.headers['Authorization'], 'Bearer voice-test-token');
        expect(
          request.headers['content-type'],
          startsWith('multipart/form-data'),
        );
        expect(request.body, contains('name="message_type"\r\n\r\naudio'));
        expect(request.body, contains('name="audio_duration"\r\n\r\n4'));
        expect(request.body, contains('filename="voice.m4a"'));
        return http.Response(jsonEncode(audioMessage()), 201);
      });
      addTearDown(client.close);
      final message =
          await MessageDataSourceImpl(
            client: client,
            tokenStorage: _Storage(),
          ).sendVoiceMessage(
            conversationId: 7,
            audioFile: file,
            durationSeconds: 4,
          );
      expect(message.isAudio, isTrue);
      expect(message.audioUrl, 'https://example.com/voice.m4a');
      expect(message.displayContent, 'Voice message');
      expect(latestSeenMessageId([message], '2', 12), 12);
      expect(latestSeenMessageId([message], '2', 11), isNull);
    },
  );

  test('failed upload preserves local recording for retry', () async {
    final directory = await Directory.systemTemp.createTemp(
      'voice_retry_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = await File(
      '${directory.path}/voice.m4a',
    ).writeAsBytes([1, 2, 3]);
    final client = MockClient((_) async => http.Response('{}', 502));
    addTearDown(client.close);
    await expectLater(
      MessageDataSourceImpl(
        client: client,
        tokenStorage: _Storage(),
      ).sendVoiceMessage(
        conversationId: 7,
        audioFile: file,
        durationSeconds: 4,
      ),
      throwsException,
    );
    expect(await file.exists(), isTrue);
  });

  testWidgets(
    'voice bubble shows playback control and duration without loading audio',
    (tester) async {
      final message = MessageModel.fromJson(audioMessage());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceMessagePlayer(
              source: message.audioUrl!,
              durationSeconds: 4,
            ),
          ),
        ),
      );
      expect(find.byTooltip('Play voice message'), findsOneWidget);
      expect(find.text('0:04'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
