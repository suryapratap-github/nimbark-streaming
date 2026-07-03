import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/models/auth_session.dart';
import '../../../core/services/api_exception.dart';

class LiveApi {
  LiveApi({
    required this.apiBaseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiBaseUrl;
  final http.Client _client;

  Future<List<LiveRoom>> liveRooms() async {
    final response =
        await _client.get(Uri.parse('$apiBaseUrl/live/rooms?status=LIVE'));
    final data = jsonDecode(response.body) as List<dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const ApiException('Unable to load live rooms');
    }

    return data.cast<Map<String, dynamic>>().map(LiveRoom.fromJson).toList();
  }

  Future<LiveRoom> createRoom({
    required AuthSession session,
    required String title,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/live/rooms'),
      headers: _headers(session.accessToken),
      body: jsonEncode({'title': title}),
    );
    final data = _decode(response);
    return LiveRoom.fromJson(data);
  }

  Future<LiveRoom> startRoom({
    required AuthSession session,
    required String roomId,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/live/rooms/$roomId/start'),
      headers: _headers(session.accessToken),
    );
    final data = _decode(response);
    return LiveRoom.fromJson(data);
  }

  Future<LiveRoom> endRoom({
    required AuthSession session,
    required String roomId,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/live/rooms/$roomId/end'),
      headers: _headers(session.accessToken),
    );
    final data = _decode(response);
    return LiveRoom.fromJson(data);
  }

  Future<LiveJoinToken> createToken({
    required AuthSession session,
    required String roomId,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/live/token'),
      headers: _headers(session.accessToken),
      body: jsonEncode({'roomId': roomId}),
    );
    final data = _decode(response);
    return LiveJoinToken.fromJson(data);
  }

  Future<List<LiveComment>> comments({
    required AuthSession session,
    required String roomId,
  }) async {
    final response = await _client.get(
      Uri.parse('$apiBaseUrl/live/rooms/$roomId/comments'),
      headers: _headers(session.accessToken),
    );
    final data = jsonDecode(response.body) as List<dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const ApiException('Unable to load live comments');
    }

    return data.cast<Map<String, dynamic>>().map(LiveComment.fromJson).toList();
  }

  Future<LiveComment> createComment({
    required AuthSession session,
    required String roomId,
    required String body,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/live/rooms/$roomId/comments'),
      headers: _headers(session.accessToken),
      body: jsonEncode({'body': body}),
    );
    final data = _decode(response);
    return LiveComment.fromJson(data);
  }

  Future<List<LiveReactionCount>> reactions({
    required AuthSession session,
    required String roomId,
  }) async {
    final response = await _client.get(
      Uri.parse('$apiBaseUrl/live/rooms/$roomId/reactions'),
      headers: _headers(session.accessToken),
    );
    final data = jsonDecode(response.body) as List<dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const ApiException('Unable to load live reactions');
    }

    return data
        .cast<Map<String, dynamic>>()
        .map(LiveReactionCount.fromJson)
        .toList();
  }

  Future<List<LiveReactionCount>> createReaction({
    required AuthSession session,
    required String roomId,
    required String emoji,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/live/rooms/$roomId/reactions'),
      headers: _headers(session.accessToken),
      body: jsonEncode({'emoji': emoji}),
    );
    final data = jsonDecode(response.body) as List<dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const ApiException('Unable to send reaction');
    }

    return data
        .cast<Map<String, dynamic>>()
        .map(LiveReactionCount.fromJson)
        .toList();
  }

  Future<void> reportRoom({
    required AuthSession session,
    required String roomId,
    required String reason,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/live/rooms/$roomId/reports'),
      headers: _headers(session.accessToken),
      body: jsonEncode({'reason': reason}),
    );
    _decode(response);
  }

  Future<LiveRoomSettings> settings({
    required AuthSession session,
    required String roomId,
  }) async {
    final response = await _client.get(
      Uri.parse('$apiBaseUrl/live/rooms/$roomId/settings'),
      headers: _headers(session.accessToken),
    );
    final data = _decode(response);
    return LiveRoomSettings.fromJson(data);
  }

  Future<LiveRoomSettings> updateSettings({
    required AuthSession session,
    required String roomId,
    bool? commentsOn,
    bool? reactionsOn,
  }) async {
    final response = await _client.patch(
      Uri.parse('$apiBaseUrl/live/rooms/$roomId/settings'),
      headers: _headers(session.accessToken),
      body: jsonEncode({
        if (commentsOn != null) 'commentsOn': commentsOn,
        if (reactionsOn != null) 'reactionsOn': reactionsOn,
      }),
    );
    final data = _decode(response);
    return LiveRoomSettings.fromJson(data);
  }

  Future<void> blockViewer({
    required AuthSession session,
    required String roomId,
    required String userId,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/live/rooms/$roomId/blocks'),
      headers: _headers(session.accessToken),
      body: jsonEncode({'userId': userId}),
    );
    _decode(response);
  }

  Future<void> unblockViewer({
    required AuthSession session,
    required String roomId,
    required String userId,
  }) async {
    final response = await _client.delete(
      Uri.parse('$apiBaseUrl/live/rooms/$roomId/blocks/$userId'),
      headers: _headers(session.accessToken),
    );
    _decode(response);
  }

  Future<void> viewerJoined({
    required AuthSession session,
    required String roomId,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/live/rooms/$roomId/viewer-joined'),
      headers: _headers(session.accessToken),
    );
    _decode(response);
  }

  Future<void> viewerLeft({
    required AuthSession session,
    required String roomId,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/live/rooms/$roomId/viewer-left'),
      headers: _headers(session.accessToken),
    );
    _decode(response);
  }

  Future<List<LiveBlockedViewer>> blockedViewers({
    required AuthSession session,
    required String roomId,
  }) async {
    final response = await _client.get(
      Uri.parse('$apiBaseUrl/live/rooms/$roomId/blocks'),
      headers: _headers(session.accessToken),
    );
    final data = jsonDecode(response.body) as List<dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const ApiException('Unable to load blocked viewers');
    }

    return data
        .cast<Map<String, dynamic>>()
        .map(LiveBlockedViewer.fromJson)
        .toList();
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
}

class LiveRoom {
  const LiveRoom({
    required this.id,
    required this.title,
    required this.status,
    this.hostName,
  });

  final String id;
  final String title;
  final String status;
  final String? hostName;

  factory LiveRoom.fromJson(Map<String, dynamic> json) {
    final host = json['host'] as Map<String, dynamic>?;
    return LiveRoom(
      id: json['id'] as String,
      title: json['title'] as String,
      status: json['status'] as String,
      hostName:
          (host?['displayName'] as String?) ?? (host?['username'] as String?),
    );
  }
}

class LiveJoinToken {
  const LiveJoinToken({
    required this.roomId,
    required this.roomName,
    required this.title,
    required this.hostName,
    required this.hostIdentity,
    required this.participantIdentity,
    required this.startedAt,
    required this.commentsOn,
    required this.reactionsOn,
    required this.recordingOn,
    required this.wsUrl,
    required this.token,
    required this.canPublish,
  });

  final String roomId;
  final String roomName;
  final String title;
  final String hostName;
  final String hostIdentity;
  final String participantIdentity;
  final DateTime? startedAt;
  final bool commentsOn;
  final bool reactionsOn;
  final bool recordingOn;
  final String wsUrl;
  final String token;
  final bool canPublish;

  factory LiveJoinToken.fromJson(Map<String, dynamic> json) {
    return LiveJoinToken(
      roomId: json['roomId'] as String,
      roomName: json['roomName'] as String,
      title: json['title'] as String,
      hostName: json['hostName'] as String,
      hostIdentity: json['hostIdentity'] as String,
      participantIdentity: json['participantIdentity'] as String? ??
          json['hostIdentity'] as String,
      startedAt: json['startedAt'] == null
          ? null
          : DateTime.parse(json['startedAt'] as String),
      commentsOn: json['commentsOn'] as bool? ?? true,
      reactionsOn: json['reactionsOn'] as bool? ?? true,
      recordingOn: json['recordingOn'] as bool? ?? false,
      wsUrl: json['wsUrl'] as String,
      token: json['token'] as String,
      canPublish: json['canPublish'] as bool,
    );
  }
}

class LiveRoomSettings {
  const LiveRoomSettings({
    required this.commentsOn,
    required this.reactionsOn,
  });

  final bool commentsOn;
  final bool reactionsOn;

  factory LiveRoomSettings.fromJson(Map<String, dynamic> json) {
    return LiveRoomSettings(
      commentsOn: json['commentsOn'] as bool? ?? true,
      reactionsOn: json['reactionsOn'] as bool? ?? true,
    );
  }
}

class LiveComment {
  const LiveComment({
    required this.id,
    required this.userId,
    required this.body,
    required this.createdAt,
    this.authorUsername,
  });

  final String id;
  final String userId;
  final String body;
  final DateTime createdAt;
  final String? authorUsername;

  factory LiveComment.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>?;
    return LiveComment(
      id: json['id'] as String,
      userId: json['userId'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      authorUsername: author?['username'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'body': body,
      'createdAt': createdAt.toIso8601String(),
      'authorUsername': authorUsername,
    };
  }

  factory LiveComment.fromRealtimeJson(Map<String, dynamic> json) {
    return LiveComment(
      id: json['id'] as String,
      userId: json['userId'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      authorUsername: json['authorUsername'] as String?,
    );
  }
}

class LiveReactionCount {
  const LiveReactionCount({
    required this.emoji,
    required this.count,
  });

  final String emoji;
  final int count;

  factory LiveReactionCount.fromJson(Map<String, dynamic> json) {
    return LiveReactionCount(
      emoji: json['emoji'] as String,
      count: json['count'] as int,
    );
  }
}

class LiveBlockedViewer {
  const LiveBlockedViewer({
    required this.userId,
    required this.username,
    required this.displayName,
  });

  final String userId;
  final String username;
  final String displayName;

  factory LiveBlockedViewer.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final userId =
        (json['userId'] as String?) ?? (user?['id'] as String? ?? '');
    final username = user?['username'] as String? ??
        'viewer-${userId.substring(0, userId.length < 6 ? userId.length : 6)}';

    return LiveBlockedViewer(
      userId: userId,
      username: username,
      displayName: user?['displayName'] as String? ?? username,
    );
  }
}
