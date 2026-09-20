import 'dart:convert';

import 'package:chat_app/core/constants/api_entpoint.dart';
import 'package:chat_app/feature/auth/data/model/login_model.dart';
import 'package:http/http.dart' as http;

abstract class LoginDataSource {
  Future<LoginModel> login({
    required String email,
    required String password,
  });
}

class LoginDataSourceImpl implements LoginDataSource {
  final http.Client client;
  LoginDataSourceImpl({required this.client});
  @override
  Future<LoginModel> login({
    required String email,
    required String password,
  }) async {
    final response = await client.post(
      Uri.parse(ApiEntpoint.login),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Login failed: ${response.body}');
    }

    return LoginModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
