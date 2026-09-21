import 'package:chat_app/core/service/token_storage.dart';
import 'package:chat_app/feature/profile/data/datasource/profile_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Storage extends TokenStorage {
  String name = 'Old name';
  @override
  Future<String?> getToken() async => 'test-token';
  @override
  Future<void> saveUserProfile({
    required String name,
    required String email,
  }) async {
    this.name = name;
  }
}

void main() {
  test(
    'profile save authenticates, uses PUT override and updates cached name',
    () async {
      final storage = _Storage();
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], 'Bearer test-token');
        expect(request.body, contains('name="_method"\r\n\r\nPUT'));
        expect(request.body, contains('name="name"\r\n\r\nNew name'));
        expect(
          request.body,
          contains('name="status_message"\r\n\r\nAvailable'),
        );
        return http.Response(
          '{"user":{"name":"New name","email":"user@example.com","status_message":"Available","avatar_url":"/storage/avatars/photo.jpg"}}',
          200,
        );
      });
      addTearDown(client.close);
      final profile = await ProfileRemoteDataSource(
        client: client,
        storage: storage,
      ).update(name: ' New name ', statusMessage: ' Available ');
      expect(profile.statusMessage, 'Available');
      expect(profile.avatarUrl, '/storage/avatars/photo.jpg');
      expect(storage.name, 'New name');
    },
  );

  test('failed save reports server error and keeps cached profile', () async {
    final storage = _Storage();
    final client = MockClient(
      (_) async =>
          http.Response('{"message":"The name field is required."}', 422),
    );
    addTearDown(client.close);
    await expectLater(
      ProfileRemoteDataSource(
        client: client,
        storage: storage,
      ).update(name: '', statusMessage: ''),
      throwsA(
        predicate(
          (error) => error.toString().contains('The name field is required.'),
        ),
      ),
    );
    expect(storage.name, 'Old name');
  });
}
