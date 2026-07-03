import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'api_exception.dart';

class LocationSyncService {
  LocationSyncService({
    required this.apiBaseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiBaseUrl;
  final http.Client _client;
  bool _syncedThisAppSession = false;

  Future<void> syncOnceAfterAuth({
    required String userId,
    required String accessToken,
  }) async {
    if (_syncedThisAppSession) {
      return;
    }

    final permission = await _ensurePermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
      timeLimit: const Duration(seconds: 10),
    );

    final response = await _client.patch(
      Uri.parse('$apiBaseUrl/users/$userId/location'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'source': 'mobile',
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const ApiException('Location sync failed');
    }

    _syncedThisAppSession = true;
  }

  Future<LocationPermission> _ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      return LocationPermission.denied;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission;
  }
}
