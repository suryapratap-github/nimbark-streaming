import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/models/auth_session.dart';
import '../../../core/services/api_exception.dart';

class NotificationsApi {
  NotificationsApi({
    required this.apiBaseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiBaseUrl;
  final http.Client _client;

  Future<List<AppNotification>> list(AuthSession session) async {
    final response = await _client.get(
      Uri.parse('$apiBaseUrl/notifications'),
      headers: _headers(session.accessToken),
    );
    final data = _decodeList(response);
    return data.map(AppNotification.fromJson).toList();
  }

  Future<int> unreadCount(AuthSession session) async {
    final response = await _client.get(
      Uri.parse('$apiBaseUrl/notifications/unread-count'),
      headers: _headers(session.accessToken),
    );
    final data = _decode(response);
    return data['count'] as int? ?? 0;
  }

  Future<void> markRead({
    required AuthSession session,
    required String id,
  }) async {
    final response = await _client.patch(
      Uri.parse('$apiBaseUrl/notifications/$id/read'),
      headers: _headers(session.accessToken),
    );
    _decode(response);
  }

  Future<void> markAllRead(AuthSession session) async {
    final response = await _client.patch(
      Uri.parse('$apiBaseUrl/notifications/read-all'),
      headers: _headers(session.accessToken),
    );
    _decode(response);
  }

  Future<void> registerDeviceToken({
    required AuthSession session,
    required String token,
    required String platform,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/notifications/device-tokens'),
      headers: _headers(session.accessToken),
      body: jsonEncode({
        'token': token,
        'platform': platform,
      }),
    );
    _decode(response);
  }

  Map<String, String> _headers(String accessToken) {
    return {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };
  }

  Map<String, dynamic> _decode(http.Response response) {
    final data = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(data['message'] as String? ?? 'Request failed');
    }

    return data;
  }

  List<Map<String, dynamic>> _decodeList(http.Response response) {
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (decoded is Map<String, dynamic>) {
        throw ApiException(decoded['message'] as String? ?? 'Request failed');
      }

      throw const ApiException('Request failed');
    }

    if (decoded is List<dynamic>) {
      return decoded.cast<Map<String, dynamic>>();
    }

    throw const ApiException('Unexpected response from server');
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
    this.data = const {},
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;
  final Map<String, dynamic> data;

  bool get isUnread => readAt == null;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'SYSTEM',
      title: json['title'] as String? ?? 'Notification',
      body: json['body'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      readAt: json['readAt'] == null
          ? null
          : DateTime.parse(json['readAt'] as String),
      data: json['data'] is Map<String, dynamic>
          ? json['data'] as Map<String, dynamic>
          : const {},
    );
  }
}
