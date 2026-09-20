import 'dart:convert';

import 'package:chat_app/core/constants/api_entpoint.dart';
import 'package:chat_app/feature/auth/data/model/register_model.dart';
import 'package:http/http.dart' as http;

abstract class RegisterDataSource {
  Future<RegisterModel> register({
    required String name,
    required String email,
    required String password,
    required String conpass,
  });
}

class RegisterDataSourceImpl implements RegisterDataSource {
  final http.Client client;
  RegisterDataSourceImpl({required this.client});
  @override
  Future<RegisterModel> register({
    required String name,
    required String email,
    required String password,
    required String conpass,
  }) async {
    final response = await client.post(
      Uri.parse(ApiEntpoint.register),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'email':email,
        'password': password,
        'password_confirmation': conpass,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Registration failed: ${response.body}');
    }

    return RegisterModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
