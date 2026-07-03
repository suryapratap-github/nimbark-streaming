import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/models/auth_session.dart';
import '../../../core/services/api_exception.dart';

class UserApi {
  UserApi({
    required this.apiBaseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiBaseUrl;
  final http.Client _client;

  Future<AuthUser> updateProfile({
    required AuthSession session,
    required String displayName,
    required String bio,
    required String avatarUrl,
  }) async {
    final response = await _client.patch(
      Uri.parse('$apiBaseUrl/users/${session.user.id}'),
      headers: _headers(session.accessToken),
      body: jsonEncode({
        'displayName': displayName,
        'bio': bio,
        'avatarUrl': avatarUrl,
      }),
    );
    final data = _decode(response);
    return AuthUser.fromJson(data);
  }

  Future<AuthUser> getProfile(AuthSession session) async {
    final response =
        await _client.get(Uri.parse('$apiBaseUrl/users/${session.user.id}'));
    final data = _decode(response);
    return AuthUser.fromJson(data);
  }

  Future<void> deleteProfile(AuthSession session) async {
    final response = await _client.delete(
      Uri.parse('$apiBaseUrl/users/${session.user.id}'),
      headers: _headers(session.accessToken),
    );
    _decode(response);
  }

  Future<List<SubscriptionPlan>> subscriptionPlans() async {
    final response =
        await _client.get(Uri.parse('$apiBaseUrl/users/subscription-plans'));
    final data = _decodeList(response);
    return data.map(SubscriptionPlan.fromJson).toList();
  }

  Future<UserSubscription?> activeSubscription(AuthSession session) async {
    final response = await _client.get(
      Uri.parse('$apiBaseUrl/users/${session.user.id}/subscription'),
      headers: _headers(session.accessToken),
    );

    final data = _decodeNullable(response);

    if (data == null) {
      return null;
    }

    return UserSubscription.fromJson(data);
  }

  Future<RevenueCatConfig> revenueCatConfig(AuthSession session) async {
    final response = await _client.get(
      Uri.parse('$apiBaseUrl/payments/revenuecat/config'),
      headers: _headers(session.accessToken),
    );
    final data = _decode(response);
    return RevenueCatConfig.fromJson(data);
  }

  Future<UserSubscription> subscribe({
    required AuthSession session,
    required String planId,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/users/${session.user.id}/subscriptions'),
      headers: _headers(session.accessToken),
      body: jsonEncode({'planId': planId}),
    );
    final data = _decode(response);
    return UserSubscription.fromJson(data);
  }

  Future<void> cancelSubscription(AuthSession session) async {
    final response = await _client.delete(
      Uri.parse('$apiBaseUrl/users/${session.user.id}/subscription'),
      headers: _headers(session.accessToken),
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
    final data = _decodeNullable(response);

    if (data == null) {
      throw const ApiException('Empty response from server');
    }

    return data;
  }

  Map<String, dynamic>? _decodeNullable(http.Response response) {
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (decoded is Map<String, dynamic>) {
        throw ApiException(decoded['message'] as String? ?? 'Request failed');
      }

      throw const ApiException('Request failed');
    }

    if (decoded == null) {
      return null;
    }

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw const ApiException('Unexpected response from server');
  }

  List<Map<String, dynamic>> _decodeList(http.Response response) {
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const ApiException('Request failed');
    }

    if (decoded is List<dynamic>) {
      return decoded.cast<Map<String, dynamic>>();
    }

    throw const ApiException('Unexpected response from server');
  }
}

class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.priceCents,
    required this.currency,
    required this.durationDays,
    this.revenueCatOfferingId,
    this.revenueCatPackageId,
    this.revenueCatEntitlementId,
    this.description,
  });

  final String id;
  final String name;
  final String? description;
  final int priceCents;
  final String currency;
  final int durationDays;
  final String? revenueCatOfferingId;
  final String? revenueCatPackageId;
  final String? revenueCatEntitlementId;

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      priceCents: json['priceCents'] as int,
      currency: json['currency'] as String,
      durationDays: json['durationDays'] as int,
      revenueCatOfferingId: json['revenueCatOfferingId'] as String?,
      revenueCatPackageId: json['revenueCatPackageId'] as String?,
      revenueCatEntitlementId: json['revenueCatEntitlementId'] as String?,
    );
  }

  String get priceLabel => '$currency ${(priceCents / 100).toStringAsFixed(2)}';
}

class RevenueCatConfig {
  const RevenueCatConfig({
    required this.iosApiKey,
    required this.androidApiKey,
    required this.defaultOfferingId,
  });

  final String iosApiKey;
  final String androidApiKey;
  final String defaultOfferingId;

  factory RevenueCatConfig.fromJson(Map<String, dynamic> json) {
    return RevenueCatConfig(
      iosApiKey: json['iosApiKey'] as String? ?? '',
      androidApiKey: json['androidApiKey'] as String? ?? '',
      defaultOfferingId: json['defaultOfferingId'] as String? ?? '',
    );
  }
}

class UserSubscription {
  const UserSubscription({
    required this.id,
    required this.status,
    required this.expiresAt,
    required this.plan,
    this.provider,
    this.externalSubscriptionId,
    this.externalProductId,
    this.latestEventAt,
    this.canceledAt,
  });

  final String id;
  final String status;
  final DateTime expiresAt;
  final SubscriptionPlan plan;
  final String? provider;
  final String? externalSubscriptionId;
  final String? externalProductId;
  final DateTime? latestEventAt;
  final DateTime? canceledAt;

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    return UserSubscription(
      id: json['id'] as String,
      status: json['status'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      plan: SubscriptionPlan.fromJson(json['plan'] as Map<String, dynamic>),
      provider: json['provider'] as String?,
      externalSubscriptionId: json['externalSubscriptionId'] as String?,
      externalProductId: json['externalProductId'] as String?,
      latestEventAt: json['latestEventAt'] == null
          ? null
          : DateTime.parse(json['latestEventAt'] as String),
      canceledAt: json['canceledAt'] == null
          ? null
          : DateTime.parse(json['canceledAt'] as String),
    );
  }
}
