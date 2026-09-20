import 'dart:convert';
import 'package:chat_app/core/service/token_storage.dart';
import 'package:http/http.dart' as http;
import 'package:chat_app/core/constants/api_entpoint.dart';

abstract class CallRemoteDataSource {
  Future<void> endCall({required String callId, required String status});
}

class CallRemotedataSource implements CallRemoteDataSource {
  CallRemotedataSource(this._tokenStorage);

  final TokenStorage _tokenStorage;

  @override
  Future<void> endCall({required String callId, required String status}) async {
    final authToken = await _tokenStorage.getToken();
    if (authToken == null) {
      throw StateError('No auth token found; cannot end call.');
    }

    final uri = Uri.parse('${ApiEntpoint.url}/calls/$callId/end');

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $authToken',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'status': status}),
    );

    if (response.statusCode != 200) {
      throw StateError(
        'Could not end call ($callId): ${response.statusCode} ${response.body}',
      );
    }
  }
}
