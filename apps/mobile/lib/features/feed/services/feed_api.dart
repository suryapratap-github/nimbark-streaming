import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/models/auth_session.dart';
import '../../../core/services/api_exception.dart';

class FeedApi {
  FeedApi({
    required this.apiBaseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiBaseUrl;
  final http.Client _client;

  Future<List<FeedItem>> videos() async {
    final response = await _client.get(Uri.parse('$apiBaseUrl/feed/videos'));
    final data = jsonDecode(response.body) as List<dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const ApiException('Unable to load videos');
    }

    return data
        .cast<Map<String, dynamic>>()
        .map((json) => FeedItem.fromJson(json, FeedItemType.video, apiBaseUrl))
        .toList();
  }

  Future<List<FeedItem>> reels() async {
    final response = await _client.get(Uri.parse('$apiBaseUrl/feed/reels'));
    final data = jsonDecode(response.body) as List<dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const ApiException('Unable to load reels');
    }

    return data
        .cast<Map<String, dynamic>>()
        .map((json) => FeedItem.fromJson(json, FeedItemType.reel, apiBaseUrl))
        .toList();
  }

  Future<FeedSearchResult> search(String query) async {
    final response = await _client.get(Uri.parse(
        '$apiBaseUrl/feed/search?q=${Uri.encodeQueryComponent(query)}'));
    final data = _decode(response);
    return FeedSearchResult.fromJson(data, apiBaseUrl);
  }

  Future<CreatorProfile> creatorProfile(String creatorId) async {
    final response =
        await _client.get(Uri.parse('$apiBaseUrl/feed/creators/$creatorId'));
    final data = _decode(response);
    return CreatorProfile.fromJson(data, apiBaseUrl);
  }

  Future<FeedItem> item({
    required FeedItemType type,
    required String id,
  }) async {
    final response =
        await _client.get(Uri.parse('$apiBaseUrl/feed/${type.path}/$id'));
    final data = _decode(response);
    return FeedItem.fromJson(data, type, apiBaseUrl);
  }

  Future<FeedProcessingStatus> processingStatus({
    required AuthSession session,
    required FeedItem item,
  }) async {
    final response = await _client.get(
      Uri.parse('$apiBaseUrl/feed/${item.type.path}/${item.id}/status'),
      headers: _headers(session.accessToken),
    );
    final data = _decode(response);
    return FeedProcessingStatus.fromJson(data);
  }

  Future<MediaSettings> mediaSettings() async {
    final response = await _client.get(Uri.parse('$apiBaseUrl/media/settings'));
    final data = _decode(response);
    return MediaSettings.fromJson(data);
  }

  Future<LocalUploadResult> uploadLocalMedia({
    required AuthSession session,
    required File file,
  }) async {
    final contentType = _contentTypeForPath(file.path);
    final uploadResponse = await _client.post(
      Uri.parse('$apiBaseUrl/media/uploads'),
      headers: _headers(session.accessToken),
      body: jsonEncode({
        'fileName': file.path.split('/').last,
        'contentType': contentType,
      }),
    );
    final upload =
        MediaUploadRequest.fromJson(_decode(uploadResponse), apiBaseUrl);

    if (upload.provider == 'R2') {
      if (upload.uploadUrl == null) {
        throw const ApiException('R2 upload URL was not returned');
      }

      final putResponse = await _client.put(
        Uri.parse(upload.uploadUrl!),
        headers: {'Content-Type': contentType},
        body: await file.readAsBytes(),
      );

      if (putResponse.statusCode < 200 || putResponse.statusCode >= 300) {
        throw const ApiException('Unable to upload media to R2');
      }

      return LocalUploadResult(
        provider: upload.provider,
        objectKey: upload.objectKey,
        publicUrl: upload.publicUrl,
        contentType: contentType,
        sizeBytes: await file.length(),
      );
    }

    if (upload.uploadUrl == null) {
      throw const ApiException('Local upload URL was not returned');
    }

    final request = http.MultipartRequest('POST', Uri.parse(upload.uploadUrl!))
      ..headers['Authorization'] = 'Bearer ${session.accessToken}'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final data = _decode(response);

    return LocalUploadResult.fromJson(data, apiBaseUrl);
  }

  Future<LocalUploadResult> uploadLocalVideo({
    required AuthSession session,
    required File file,
  }) {
    return uploadLocalMedia(session: session, file: file);
  }

  Future<FeedItem> publishVideo({
    required AuthSession session,
    required String title,
    required String description,
    required LocalUploadResult upload,
    LocalUploadResult? thumbnail,
    Duration? duration,
    required bool commentsEnabled,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/feed/videos'),
      headers: _headers(session.accessToken),
      body: jsonEncode({
        'title': title,
        'description': description,
        ...upload.toPublishJson(),
        if (thumbnail != null) 'thumbnail': thumbnail.toPublishJson(),
        if (duration != null) 'durationMs': duration.inMilliseconds,
        'commentsEnabled': commentsEnabled,
      }),
    );
    final data = _decode(response);
    return FeedItem.fromJson(data, FeedItemType.video, apiBaseUrl);
  }

  Future<FeedItem> publishReel({
    required AuthSession session,
    required String caption,
    required LocalUploadResult upload,
    LocalUploadResult? thumbnail,
    required Duration duration,
    required bool commentsEnabled,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/feed/reels'),
      headers: _headers(session.accessToken),
      body: jsonEncode({
        'caption': caption,
        ...upload.toPublishJson(),
        if (thumbnail != null) 'thumbnail': thumbnail.toPublishJson(),
        'durationMs': duration.inMilliseconds,
        'commentsEnabled': commentsEnabled,
      }),
    );
    final data = _decode(response);
    return FeedItem.fromJson(data, FeedItemType.reel, apiBaseUrl);
  }

  Future<ViewTrackResult> trackView({
    required AuthSession session,
    required FeedItem item,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/feed/${item.type.path}/${item.id}/views'),
      headers: _headers(session.accessToken),
    );
    final data = _decode(response);
    return ViewTrackResult.fromJson(data);
  }

  Future<void> toggleLike({
    required AuthSession session,
    required FeedItem item,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/feed/${item.type.path}/${item.id}/likes'),
      headers: _headers(session.accessToken),
    );
    _decode(response);
  }

  Future<void> toggleDislike({
    required AuthSession session,
    required FeedItem item,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/feed/${item.type.path}/${item.id}/dislikes'),
      headers: _headers(session.accessToken),
    );
    _decode(response);
  }

  Future<void> share({
    required AuthSession session,
    required FeedItem item,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/feed/${item.type.path}/${item.id}/shares'),
      headers: _headers(session.accessToken),
    );
    _decode(response);
  }

  Future<void> reportPost({
    required AuthSession session,
    required FeedItem item,
    required String reason,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/feed/${item.type.path}/${item.id}/reports'),
      headers: _headers(session.accessToken),
      body: jsonEncode({'reason': reason}),
    );
    _decode(response);
  }

  Future<void> deletePost({
    required AuthSession session,
    required FeedItem item,
  }) async {
    final response = await _client.delete(
      Uri.parse('$apiBaseUrl/feed/${item.type.path}/${item.id}'),
      headers: _headers(session.accessToken),
    );
    _decode(response);
  }

  Future<void> reportCreator({
    required AuthSession session,
    required String creatorId,
    required String reason,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/users/$creatorId/reports'),
      headers: _headers(session.accessToken),
      body: jsonEncode({'reason': reason}),
    );
    _decode(response);
  }

  Future<void> toggleCreatorLike({
    required AuthSession session,
    required String creatorId,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/users/$creatorId/likes'),
      headers: _headers(session.accessToken),
    );
    _decode(response);
  }

  Future<void> shareCreator({
    required AuthSession session,
    required String creatorId,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/users/$creatorId/shares'),
      headers: _headers(session.accessToken),
    );
    _decode(response);
  }

  Future<List<FeedComment>> comments(FeedItem item) async {
    final response = await _client.get(
        Uri.parse('$apiBaseUrl/feed/${item.type.path}/${item.id}/comments'));
    final data = _decodeList(response);
    return data.map(FeedComment.fromJson).toList();
  }

  Future<FeedComment> createComment({
    required AuthSession session,
    required FeedItem item,
    required String body,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/feed/${item.type.path}/${item.id}/comments'),
      headers: _headers(session.accessToken),
      body: jsonEncode({'body': body}),
    );
    final data = _decode(response);
    return FeedComment.fromJson(data);
  }

  Future<void> deleteComment({
    required AuthSession session,
    required FeedItem item,
    required FeedComment comment,
  }) async {
    final response = await _client.delete(
      Uri.parse(
          '$apiBaseUrl/feed/${item.type.path}/${item.id}/comments/${comment.id}'),
      headers: _headers(session.accessToken),
    );
    _decode(response);
  }

  Future<void> reportComment({
    required AuthSession session,
    required FeedItem item,
    required FeedComment comment,
    required String reason,
  }) async {
    final response = await _client.post(
      Uri.parse(
          '$apiBaseUrl/feed/${item.type.path}/${item.id}/comments/${comment.id}/reports'),
      headers: _headers(session.accessToken),
      body: jsonEncode({'reason': reason}),
    );
    _decode(response);
  }

  Future<void> followCreator({
    required AuthSession session,
    required String creatorId,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/users/$creatorId/followers'),
      headers: _headers(session.accessToken),
    );
    _decode(response);
  }

  Future<void> unfollowCreator({
    required AuthSession session,
    required String creatorId,
  }) async {
    final response = await _client.delete(
      Uri.parse('$apiBaseUrl/users/$creatorId/followers/me'),
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

class MediaUploadRequest {
  const MediaUploadRequest({
    required this.provider,
    required this.objectKey,
    required this.contentType,
    required this.uploadUrl,
    required this.publicUrl,
    required this.method,
  });

  final String provider;
  final String objectKey;
  final String contentType;
  final String? uploadUrl;
  final String publicUrl;
  final String method;

  factory MediaUploadRequest.fromJson(
      Map<String, dynamic> json, String apiBaseUrl) {
    return MediaUploadRequest(
      provider: json['provider'] as String? ?? 'LOCAL',
      objectKey: json['objectKey'] as String,
      contentType: json['contentType'] as String,
      uploadUrl: json['uploadUrl'] == null
          ? null
          : _absoluteMediaUrl(json['uploadUrl'] as String, apiBaseUrl),
      publicUrl:
          _absoluteMediaUrl(json['publicUrl'] as String? ?? '', apiBaseUrl),
      method: json['method'] as String? ?? 'POST',
    );
  }
}

enum FeedItemType { video, reel }

extension FeedItemTypePath on FeedItemType {
  String get path => this == FeedItemType.video ? 'video' : 'reel';
}

class MediaSettings {
  const MediaSettings({
    required this.videoCompressionEnabled,
  });

  final bool videoCompressionEnabled;

  factory MediaSettings.fromJson(Map<String, dynamic> json) {
    return MediaSettings(
      videoCompressionEnabled:
          json['videoCompressionEnabled'] as bool? ?? false,
    );
  }
}

class ViewTrackResult {
  const ViewTrackResult({
    required this.counted,
    required this.viewCount,
  });

  final bool counted;
  final int viewCount;

  factory ViewTrackResult.fromJson(Map<String, dynamic> json) {
    return ViewTrackResult(
      counted: json['counted'] as bool? ?? false,
      viewCount: json['viewCount'] as int? ?? 0,
    );
  }
}

class FeedProcessingStatus {
  const FeedProcessingStatus({
    required this.status,
    this.processingStatus,
    this.errorMessage,
  });

  final String status;
  final String? processingStatus;
  final String? errorMessage;

  bool get isPublished => status == 'PUBLISHED';
  bool get isRejected => status == 'REJECTED';
  bool get isTerminalFailure => isRejected || processingStatus == 'FAILED';

  factory FeedProcessingStatus.fromJson(Map<String, dynamic> json) {
    return FeedProcessingStatus(
      status: json['status'] as String? ?? 'PROCESSING',
      processingStatus: json['processingStatus'] as String?,
      errorMessage: json['errorMessage'] as String?,
    );
  }
}

class LocalUploadResult {
  const LocalUploadResult({
    required this.provider,
    required this.objectKey,
    required this.publicUrl,
    required this.contentType,
    required this.sizeBytes,
  });

  final String provider;
  final String objectKey;
  final String publicUrl;
  final String contentType;
  final int sizeBytes;

  factory LocalUploadResult.fromJson(
      Map<String, dynamic> json, String apiBaseUrl) {
    return LocalUploadResult(
      provider: json['provider'] as String? ?? 'LOCAL',
      objectKey: json['objectKey'] as String,
      publicUrl:
          _absoluteMediaUrl(json['publicUrl'] as String? ?? '', apiBaseUrl),
      contentType: json['contentType'] as String,
      sizeBytes: json['sizeBytes'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toPublishJson() {
    return {
      'objectKey': objectKey,
      'provider': provider,
      'publicUrl': publicUrl,
      'contentType': contentType,
      'sizeBytes': sizeBytes,
    };
  }
}

class FeedItem {
  const FeedItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.mediaUrl,
    this.thumbnailUrl,
    required this.creatorId,
    required this.creatorUsername,
    required this.createdAt,
    required this.commentCount,
    required this.likeCount,
    required this.dislikeCount,
    required this.shareCount,
    required this.viewCount,
    required this.commentsEnabled,
  });

  final String id;
  final FeedItemType type;
  final String title;
  final String subtitle;
  final String mediaUrl;
  final String? thumbnailUrl;
  final String creatorId;
  final String creatorUsername;
  final DateTime createdAt;
  final int commentCount;
  final int likeCount;
  final int dislikeCount;
  final int shareCount;
  final int viewCount;
  final bool commentsEnabled;

  factory FeedItem.fromJson(
      Map<String, dynamic> json, FeedItemType type, String apiBaseUrl) {
    final mediaAsset = json['mediaAsset'] as Map<String, dynamic>;
    final thumbnail = json['thumbnail'] as Map<String, dynamic>?;
    final creator = json['creator'] as Map<String, dynamic>;
    final counts = json['_count'] as Map<String, dynamic>? ?? const {};

    return FeedItem(
      id: json['id'] as String,
      type: type,
      title: type == FeedItemType.video
          ? json['title'] as String? ?? 'Untitled video'
          : json['caption'] as String? ?? 'Reel',
      subtitle: type == FeedItemType.video
          ? json['description'] as String? ?? ''
          : '',
      mediaUrl: _absoluteMediaUrl(
          mediaAsset['publicUrl'] as String? ?? '', apiBaseUrl),
      thumbnailUrl: thumbnail == null
          ? null
          : _absoluteMediaUrl(
              thumbnail['publicUrl'] as String? ?? '',
              apiBaseUrl,
            ),
      creatorId: creator['id'] as String,
      creatorUsername: creator['username'] as String? ?? 'creator',
      createdAt: DateTime.parse(json['createdAt'] as String),
      commentCount: counts['comments'] as int? ?? 0,
      likeCount: counts['likes'] as int? ?? 0,
      dislikeCount: counts['dislikes'] as int? ?? 0,
      shareCount: counts['shares'] as int? ?? 0,
      viewCount: json['viewCount'] as int? ?? 0,
      commentsEnabled: json['commentsEnabled'] as bool? ?? true,
    );
  }
}

class FeedComment {
  const FeedComment({
    required this.id,
    required this.authorId,
    required this.body,
    required this.username,
    required this.createdAt,
  });

  final String id;
  final String authorId;
  final String body;
  final String username;
  final DateTime createdAt;

  factory FeedComment.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>;
    return FeedComment(
      id: json['id'] as String,
      authorId: author['id'] as String? ?? '',
      body: json['body'] as String,
      username: author['username'] as String? ?? 'user',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class CreatorSearchItem {
  const CreatorSearchItem({
    required this.id,
    required this.displayName,
    required this.username,
    required this.followerCount,
    required this.videoCount,
    required this.reelCount,
    required this.likeCount,
    required this.shareCount,
    this.bio,
    this.avatarUrl,
  });

  final String id;
  final String displayName;
  final String username;
  final String? bio;
  final String? avatarUrl;
  final int followerCount;
  final int videoCount;
  final int reelCount;
  final int likeCount;
  final int shareCount;

  factory CreatorSearchItem.fromJson(Map<String, dynamic> json) {
    final counts = json['_count'] as Map<String, dynamic>? ?? const {};
    return CreatorSearchItem(
      id: json['id'] as String,
      displayName: json['displayName'] as String? ?? 'Creator',
      username: json['username'] as String? ?? 'creator',
      bio: json['bio'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      followerCount: counts['followers'] as int? ?? 0,
      videoCount: counts['videos'] as int? ?? 0,
      reelCount: counts['reels'] as int? ?? 0,
      likeCount: counts['creatorLikesReceived'] as int? ?? 0,
      shareCount: counts['creatorSharesReceived'] as int? ?? 0,
    );
  }
}

class CreatorProfile {
  const CreatorProfile({
    required this.creator,
    required this.videos,
    required this.reels,
  });

  final CreatorSearchItem creator;
  final List<FeedItem> videos;
  final List<FeedItem> reels;

  factory CreatorProfile.fromJson(
      Map<String, dynamic> json, String apiBaseUrl) {
    return CreatorProfile(
      creator:
          CreatorSearchItem.fromJson(json['creator'] as Map<String, dynamic>),
      videos: (json['videos'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(
              (item) => FeedItem.fromJson(item, FeedItemType.video, apiBaseUrl))
          .toList(),
      reels: (json['reels'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map((item) => FeedItem.fromJson(item, FeedItemType.reel, apiBaseUrl))
          .toList(),
    );
  }
}

class FeedSearchResult {
  const FeedSearchResult({
    required this.creators,
    required this.videos,
    required this.reels,
  });

  final List<CreatorSearchItem> creators;
  final List<FeedItem> videos;
  final List<FeedItem> reels;

  factory FeedSearchResult.fromJson(
      Map<String, dynamic> json, String apiBaseUrl) {
    return FeedSearchResult(
      creators: (json['creators'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(CreatorSearchItem.fromJson)
          .toList(),
      videos: (json['videos'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(
              (item) => FeedItem.fromJson(item, FeedItemType.video, apiBaseUrl))
          .toList(),
      reels: (json['reels'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map((item) => FeedItem.fromJson(item, FeedItemType.reel, apiBaseUrl))
          .toList(),
    );
  }
}

String _absoluteMediaUrl(String url, String apiBaseUrl) {
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return url;
  }

  final apiUri = Uri.parse(apiBaseUrl);
  final origin = '${apiUri.scheme}://${apiUri.authority}';

  if (url.startsWith('/')) {
    return '$origin$url';
  }

  return '$origin/$url';
}

String _contentTypeForPath(String path) {
  final extension = path.toLowerCase().split('.').last;
  return switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'mov' => 'video/quicktime',
    'm4v' => 'video/x-m4v',
    'webm' => 'video/webm',
    _ => 'video/mp4',
  };
}
