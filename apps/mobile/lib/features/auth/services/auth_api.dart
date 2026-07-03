import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/models/auth_session.dart';

class AuthApi {
  AuthApi({
    required this.apiBaseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiBaseUrl;
  final http.Client _client;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) {
    return _authRequest('/auth/login', {
      'email': email,
      'password': password,
    });
  }

  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
    required String username,
  }) {
    return _authRequest('/auth/register', {
      'email': email,
      'password': password,
      'displayName': displayName,
      'username': username,
    });
  }

  Future<ForgotPasswordResult> forgotPassword({
    required String email,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    final data = _decodeObject(response);

    return ForgotPasswordResult.fromJson(data);
  }

  Future<String> resetPassword({
    required String token,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token,
        'password': password,
      }),
    );
    final data = _decodeObject(response);

    return data['message'] as String? ?? 'Password reset successfully';
  }

  Future<String> changePassword({
    required AuthSession session,
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/auth/change-password'),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );
    final data = _decodeObject(response);

    return data['message'] as String? ?? 'Password changed successfully';
  }

  Future<AuthSession> _authRequest(
      String path, Map<String, String> body) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final data = _decodeObject(response);

    return AuthSession.fromJson(data);
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    final data = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthApiException(
          data['message'] as String? ?? 'Authentication failed');
    }

    return data;
  }
}

class ForgotPasswordResult {
  const ForgotPasswordResult({
    required this.message,
    this.resetToken,
  });

  final String message;
  final String? resetToken;

  factory ForgotPasswordResult.fromJson(Map<String, dynamic> json) {
    return ForgotPasswordResult(
      message: json['message'] as String? ?? 'Reset code generated',
      resetToken: json['resetToken'] as String?,
    );
  }
}

class AuthApiException implements Exception {
  const AuthApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
