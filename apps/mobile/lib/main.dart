import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:permission_handler/permission_handler.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';

import 'core/config/app_config.dart';
import 'core/models/auth_session.dart';
import 'core/services/api_exception.dart';
import 'features/auth/services/auth_api.dart';
import 'features/auth/widgets/auth_gate.dart';
import 'features/feed/services/feed_api.dart';
import 'features/live/services/live_api.dart';
import 'features/notifications/services/notifications_api.dart';
import 'features/profile/services/user_api.dart';

bool _firebaseReady = false;
const _themePreferenceKey = 'nimbark_theme_mode';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await _initializeFirebase();
}

Future<void> _initializeFirebase() async {
  if (_firebaseReady) {
    return;
  }

  try {
    await Firebase.initializeApp();
    _firebaseReady = true;
  } catch (_) {
    _firebaseReady = false;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeFirebase();
  if (_firebaseReady) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
  runApp(const NimbarkApp());
}

enum AppThemePreference {
  system,
  light,
  dark;

  ThemeMode get themeMode {
    return switch (this) {
      AppThemePreference.system => ThemeMode.system,
      AppThemePreference.light => ThemeMode.light,
      AppThemePreference.dark => ThemeMode.dark,
    };
  }

  String get label {
    return switch (this) {
      AppThemePreference.system => 'System',
      AppThemePreference.light => 'Light',
      AppThemePreference.dark => 'Dark',
    };
  }

  IconData get icon {
    return switch (this) {
      AppThemePreference.system => Icons.brightness_auto_outlined,
      AppThemePreference.light => Icons.light_mode_outlined,
      AppThemePreference.dark => Icons.dark_mode_outlined,
    };
  }
}

Color _themeAlpha(Color color, double opacity) {
  return color.withAlpha((opacity.clamp(0, 1) * 255).round());
}

class NimbarkApp extends StatefulWidget {
  const NimbarkApp({super.key});

  @override
  State<NimbarkApp> createState() => _NimbarkAppState();
}

class _NimbarkAppState extends State<NimbarkApp> {
  AppThemePreference _themePreference = AppThemePreference.system;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_themePreferenceKey);
    AppThemePreference? preference;

    for (final value in AppThemePreference.values) {
      if (value.name == saved) {
        preference = value;
        break;
      }
    }

    final selectedPreference = preference;

    if (selectedPreference != null && mounted) {
      setState(() => _themePreference = selectedPreference);
    }
  }

  Future<void> _setThemePreference(AppThemePreference preference) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themePreferenceKey, preference.name);

    if (mounted) {
      setState(() => _themePreference = preference);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nimbark',
      debugShowCheckedModeBanner: false,
      themeMode: _themePreference.themeMode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: AuthGate(
        builder: (session, logout, updateSession) {
          return AppShell(
            session: session,
            logout: logout,
            updateSession: updateSession,
            themePreference: _themePreference,
            onThemePreferenceChanged: _setThemePreference,
          );
        },
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2F6B4F),
      brightness: brightness,
    );

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surfaceContainerLowest,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colorScheme.surfaceContainerLowest,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: colorScheme.surfaceTint,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
      badgeTheme: BadgeThemeData(backgroundColor: colorScheme.primary),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        selectedColor: colorScheme.secondaryContainer,
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outlineVariant),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _themeAlpha(colorScheme.surfaceContainerHighest, 0.58),
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        tileColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest,
        indicatorColor: colorScheme.secondaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      useMaterial3: true,
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    required this.session,
    required this.logout,
    required this.updateSession,
    required this.themePreference,
    required this.onThemePreferenceChanged,
    super.key,
  });

  final AuthSession session;
  final VoidCallback logout;
  final Future<void> Function(AuthSession session) updateSession;
  final AppThemePreference themePreference;
  final ValueChanged<AppThemePreference> onThemePreferenceChanged;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _notificationsApi = NotificationsApi(apiBaseUrl: AppConfig.apiBaseUrl);
  final _feedApi = FeedApi(apiBaseUrl: AppConfig.apiBaseUrl);
  final _liveApi = LiveApi(apiBaseUrl: AppConfig.apiBaseUrl);
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  int currentIndex = 0;
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _setupPushNotifications();
    _refreshUnreadNotifications();
  }

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.session.user.id != widget.session.user.id ||
        oldWidget.session.accessToken != widget.session.accessToken) {
      _setupPushNotifications();
      _refreshUnreadNotifications();
    }
  }

  @override
  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _messageOpenedSubscription?.cancel();
    super.dispose();
  }

  Future<void> _setupPushNotifications() async {
    if (!_firebaseReady) {
      return;
    }

    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final token = await messaging.getToken();
    if (token != null) {
      await _registerPushToken(token);
    }

    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription =
        messaging.onTokenRefresh.listen(_registerPushToken);

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openRemoteNotification(initialMessage);
      });
    }

    await _messageOpenedSubscription?.cancel();
    _messageOpenedSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen(_openRemoteNotification);
  }

  Future<void> _registerPushToken(String token) async {
    try {
      await _notificationsApi.registerDeviceToken(
        session: widget.session,
        token: token,
        platform: Platform.isIOS ? 'ios' : 'android',
      );
    } catch (_) {}
  }

  Future<void> _refreshUnreadNotifications() async {
    try {
      final count = await _notificationsApi.unreadCount(widget.session);

      if (mounted) {
        setState(() => _unreadNotifications = count);
      }
    } catch (_) {}
  }

  Future<void> _openRemoteNotification(RemoteMessage message) {
    _refreshUnreadNotifications();
    return _openNotificationData(message.data);
  }

  Future<void> _openAppNotification(AppNotification notification) {
    _refreshUnreadNotifications();
    return _openNotificationData({
      ...notification.data,
      'type': notification.type,
    });
  }

  Future<void> _openNotificationData(Map<String, dynamic> data) async {
    if (!mounted) {
      return;
    }

    final type = data['type']?.toString();

    try {
      if (type == 'COMMENT') {
        await _openPostNotification(data);
        return;
      }

      if (type == 'LIVE_STARTED') {
        await _openLiveNotification(data);
        return;
      }

      if (type == 'FOLLOW') {
        await _openFollowNotification(data);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _openPostNotification(Map<String, dynamic> data) async {
    final postId = data['postId']?.toString();
    final postType = _feedItemTypeFromPayload(data['postType']?.toString());

    if (postId == null || postType == null) {
      return;
    }

    final item = await _feedApi.item(type: postType, id: postId);

    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FeedDetailPage(
          item: item,
          session: widget.session,
          feedApi: _feedApi,
        ),
      ),
    );
  }

  Future<void> _openLiveNotification(Map<String, dynamic> data) async {
    final roomId = data['roomId']?.toString();

    if (roomId == null) {
      return;
    }

    final joinToken = await _liveApi.createToken(
      session: widget.session,
      roomId: roomId,
    );

    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveKitRoomPage(
          session: widget.session,
          liveApi: _liveApi,
          joinToken: joinToken,
        ),
      ),
    );
  }

  Future<void> _openFollowNotification(Map<String, dynamic> data) async {
    final creatorId = data['followingId']?.toString();

    if (creatorId == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreatorProfilePage(
          creatorId: creatorId,
          session: widget.session,
          feedApi: _feedApi,
        ),
      ),
    );
  }

  FeedItemType? _feedItemTypeFromPayload(String? value) {
    return switch (value) {
      'video' || 'VIDEO' => FeedItemType.video,
      'reel' || 'REEL' => FeedItemType.reel,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      FeedPage(session: widget.session),
      UploadPage(session: widget.session),
      LivePage(session: widget.session),
      NotificationsPage(
        session: widget.session,
        onOpenNotification: _openAppNotification,
        onUnreadCountChanged: (count) =>
            setState(() => _unreadNotifications = count),
      ),
      ProfilePage(
        session: widget.session,
        logout: widget.logout,
        updateSession: widget.updateSession,
        themePreference: widget.themePreference,
        onThemePreferenceChanged: widget.onThemePreferenceChanged,
      ),
    ];

    return Scaffold(
      body: pages[currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) => setState(() => currentIndex = index),
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.play_circle_outline), label: 'Feed'),
          const NavigationDestination(
              icon: Icon(Icons.add_box_outlined), label: 'Upload'),
          const NavigationDestination(icon: Icon(Icons.sensors), label: 'Live'),
          NavigationDestination(
              icon: _NotificationNavIcon(count: _unreadNotifications),
              label: 'Notifications'),
          const NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

class _NotificationNavIcon extends StatelessWidget {
  const _NotificationNavIcon({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return const Icon(Icons.notifications_outlined);
    }

    final label = count > 99 ? '99+' : '$count';

    return Badge(
      label: Text(label),
      child: const Icon(Icons.notifications_outlined),
    );
  }
}

class _PageIntro extends StatelessWidget {
  const _PageIntro({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _themeAlpha(colorScheme.primaryContainer, 0.64),
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: colorScheme.onPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _SurfacePanel extends StatelessWidget {
  const _SurfacePanel({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ],
    );
  }
}

class _PostActionButton extends StatelessWidget {
  const _PostActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? colorScheme.primary : null,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: isActive ? colorScheme.primary : null,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class FeedPage extends StatefulWidget {
  const FeedPage({
    required this.session,
    super.key,
  });

  final AuthSession session;

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final _feedApi = FeedApi(apiBaseUrl: AppConfig.apiBaseUrl);
  late Future<List<FeedItem>> _feedFuture;
  Future<FeedSearchResult>? _searchFuture;
  FeedItemType _feedType = FeedItemType.video;

  @override
  void initState() {
    super.initState();
    _feedFuture = _loadFeed();
  }

  Future<List<FeedItem>> _loadFeed() {
    return _feedType == FeedItemType.video
        ? _feedApi.videos()
        : _feedApi.reels();
  }

  void _setFeedType(FeedItemType type) {
    if (_feedType == type) {
      return;
    }

    setState(() {
      _feedType = type;
      _feedFuture = _loadFeed();
    });
  }

  Future<void> _refreshFeed() async {
    setState(() {
      _feedFuture = _loadFeed();
    });
    await _feedFuture;
  }

  Future<void> _openCreatorDashboard() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreatorDashboardPage(
          session: widget.session,
          feedApi: _feedApi,
        ),
      ),
    );

    if (mounted) {
      await _refreshFeed();
    }
  }

  void _setSearchQuery(String value) {
    final query = value.trim();
    setState(() {
      _searchFuture = query.length >= 2 ? _feedApi.search(query) : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed'),
        actions: [
          if (widget.session.user.role == 'CREATOR' ||
              widget.session.user.role == 'ADMIN')
            IconButton(
              onPressed: _openCreatorDashboard,
              icon: const Icon(Icons.dashboard_outlined),
              tooltip: 'Creator dashboard',
            ),
          IconButton(
            onPressed: _refreshFeed,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _PageIntro(
              title: _feedType == FeedItemType.video
                  ? 'Watch videos'
                  : 'Catch reels',
              subtitle:
                  'Discover creators, follow profiles, and react to fresh posts.',
              icon: _feedType == FeedItemType.video
                  ? Icons.play_circle_outline
                  : Icons.video_library_outlined,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search creators, videos, reels',
              ),
              onChanged: _setSearchQuery,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SegmentedButton<FeedItemType>(
              segments: const [
                ButtonSegment(
                    value: FeedItemType.video,
                    label: Text('Videos'),
                    icon: Icon(Icons.play_circle_outline)),
                ButtonSegment(
                    value: FeedItemType.reel,
                    label: Text('Reels'),
                    icon: Icon(Icons.video_library_outlined)),
              ],
              selected: {_feedType},
              onSelectionChanged: (selection) => _setFeedType(selection.first),
            ),
          ),
          Expanded(
            child: _searchFuture != null
                ? _SearchResultsView(
                    future: _searchFuture!,
                    session: widget.session,
                    feedApi: _feedApi,
                  )
                : FutureBuilder<List<FeedItem>>(
                    future: _feedFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return _InlineState(
                          icon: Icons.error_outline,
                          title: 'Unable to load feed',
                          subtitle: snapshot.error.toString(),
                          actionLabel: 'Retry',
                          onAction: _refreshFeed,
                        );
                      }

                      final items = snapshot.data ?? const [];

                      if (items.isEmpty) {
                        return const _InlineState(
                          icon: Icons.play_circle_outline,
                          title: 'No posts yet',
                          subtitle:
                              'Creator videos and reels will appear here.',
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: _refreshFeed,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemBuilder: (context, index) => _FeedItemCard(
                            item: items[index],
                            session: widget.session,
                            feedApi: _feedApi,
                          ),
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 14),
                          itemCount: items.length,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class UploadPage extends StatefulWidget {
  const UploadPage({
    required this.session,
    super.key,
  });

  final AuthSession session;

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  static const _maxReelDuration = Duration(seconds: 30);

  final _feedApi = FeedApi(apiBaseUrl: AppConfig.apiBaseUrl);
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  FeedItemType _postType = FeedItemType.video;
  File? _selectedFile;
  Duration? _selectedDuration;
  bool _commentsEnabled = true;
  bool _isPublishing = false;
  String? _message;

  bool get _canCreate =>
      widget.session.user.role == 'CREATOR' ||
      widget.session.user.role == 'ADMIN';

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
      withData: false,
    );
    final path = result?.files.single.path;

    if (path == null) {
      return;
    }

    final file = File(path);

    setState(() {
      _message = 'Checking video duration...';
    });

    final duration = await _readVideoDuration(file);

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedFile = file;
      _selectedDuration = duration;
      _message = duration == null
          ? 'Could not read video duration. Pick another video.'
          : null;
      if (_titleController.text.trim().isEmpty) {
        _titleController.text =
            result!.files.single.name.replaceAll(RegExp(r'\.[^.]+$'), '');
      }
    });
  }

  Future<Duration?> _readVideoDuration(File file) async {
    final controller = VideoPlayerController.file(file);

    try {
      await controller.initialize();
      return controller.value.duration;
    } catch (_) {
      return null;
    } finally {
      await controller.dispose();
    }
  }

  Future<void> _publish() async {
    final file = _selectedFile;

    if (file == null || _isPublishing) {
      return;
    }

    if (_postType == FeedItemType.video &&
        _titleController.text.trim().isEmpty) {
      setState(() => _message = 'Add a title before publishing.');
      return;
    }

    final duration = _selectedDuration;

    if (duration == null) {
      setState(() =>
          _message = 'Could not read video duration. Pick another video.');
      return;
    }

    if (_postType == FeedItemType.reel && duration > _maxReelDuration) {
      setState(() => _message = 'Reels must be 30 seconds or shorter.');
      return;
    }

    setState(() {
      _isPublishing = true;
      _message = 'Checking media settings...';
    });

    try {
      final settings = await _feedApi.mediaSettings();
      if (!mounted) {
        return;
      }
      File uploadFile = file;

      setState(() => _message = 'Generating thumbnail...');
      final thumbnailFile = await VideoCompress.getFileThumbnail(
        file.path,
        quality: 75,
        position: 1,
      );
      final thumbnailUpload = await _feedApi.uploadLocalMedia(
        session: widget.session,
        file: thumbnailFile,
      );
      if (!mounted) {
        return;
      }

      if (settings.videoCompressionEnabled) {
        setState(() => _message = 'Compressing video...');
        final compressed = await VideoCompress.compressVideo(
          file.path,
          quality: VideoQuality.MediumQuality,
          deleteOrigin: false,
          includeAudio: true,
        );
        final compressedPath = compressed?.path;

        if (compressedPath == null || compressedPath.isEmpty) {
          throw const ApiException(
              'Video compression failed. Try another video.');
        }

        uploadFile = File(compressedPath);
        if (!mounted) {
          return;
        }
      }

      setState(() => _message = 'Uploading video...');
      final upload = await _feedApi.uploadLocalVideo(
        session: widget.session,
        file: uploadFile,
      );
      if (!mounted) {
        return;
      }

      setState(() => _message = 'Publishing...');

      if (_postType == FeedItemType.video) {
        await _feedApi.publishVideo(
          session: widget.session,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          upload: upload,
          thumbnail: thumbnailUpload,
          duration: duration,
          commentsEnabled: _commentsEnabled,
        );
      } else {
        await _feedApi.publishReel(
          session: widget.session,
          caption: _descriptionController.text.trim(),
          upload: upload,
          thumbnail: thumbnailUpload,
          duration: duration,
          commentsEnabled: _commentsEnabled,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedFile = null;
        _selectedDuration = null;
        _commentsEnabled = true;
        _titleController.clear();
        _descriptionController.clear();
        _message = 'Upload queued for processing.';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _message = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_canCreate) {
      return const FeaturePage(
        title: 'Upload',
        subtitle: 'Creator access is required before uploading content',
        icon: Icons.lock_outline,
      );
    }

    final selectedFile = _selectedFile;

    return Scaffold(
      appBar: AppBar(title: const Text('Upload')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _PageIntro(
            title: 'Create a post',
            subtitle:
                'Upload videos or short reels with comments and thumbnails.',
            icon: Icons.cloud_upload_outlined,
          ),
          const SizedBox(height: 16),
          _SurfacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<FeedItemType>(
                  segments: const [
                    ButtonSegment(
                        value: FeedItemType.video,
                        label: Text('Video'),
                        icon: Icon(Icons.play_circle_outline)),
                    ButtonSegment(
                        value: FeedItemType.reel,
                        label: Text('Reel'),
                        icon: Icon(Icons.video_library_outlined)),
                  ],
                  selected: {_postType},
                  onSelectionChanged: (selection) => setState(() {
                    _postType = selection.first;
                    if (_postType == FeedItemType.reel &&
                        _selectedDuration != null &&
                        _selectedDuration! > _maxReelDuration) {
                      _message = 'Reels must be 30 seconds or shorter.';
                    } else if (_message ==
                        'Reels must be 30 seconds or shorter.') {
                      _message = null;
                    }
                  }),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _isPublishing ? null : _pickVideo,
                  icon: const Icon(Icons.folder_open),
                  label: Text(selectedFile == null
                      ? 'Pick saved video'
                      : selectedFile.path.split('/').last),
                ),
                if (_selectedDuration != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _MetaPill(
                      icon: Icons.timer_outlined,
                      label:
                          'Duration ${_formatUploadDuration(_selectedDuration!)}',
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (_postType == FeedItemType.video)
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      prefixIcon: Icon(Icons.title),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                if (_postType == FeedItemType.video) const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: _postType == FeedItemType.video
                        ? 'Description'
                        : 'Caption',
                    prefixIcon: const Icon(Icons.notes_outlined),
                  ),
                  minLines: 3,
                  maxLines: 5,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _commentsEnabled,
                  onChanged: _isPublishing
                      ? null
                      : (value) => setState(() => _commentsEnabled = value),
                  title: const Text('Allow comments'),
                  subtitle: Text(_commentsEnabled
                      ? 'Users can comment on this post.'
                      : 'Comments will be disabled.'),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed:
                      selectedFile == null || _isPublishing ? null : _publish,
                  icon: _isPublishing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.cloud_upload_outlined),
                  label: Text(_isPublishing ? 'Publishing' : 'Publish'),
                ),
              ],
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            _SurfacePanel(
              child: Text(
                _message!,
                style: TextStyle(
                  color: _message == 'Published successfully.' ||
                          _message == 'Upload queued for processing.'
                      ? Theme.of(context).colorScheme.primary
                      : null,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchResultsView extends StatelessWidget {
  const _SearchResultsView({
    required this.future,
    required this.session,
    required this.feedApi,
  });

  final Future<FeedSearchResult> future;
  final AuthSession session;
  final FeedApi feedApi;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FeedSearchResult>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _InlineState(
            icon: Icons.search_off,
            title: 'Search failed',
            subtitle: snapshot.error.toString(),
          );
        }

        final result = snapshot.data;
        final creators = result?.creators ?? const [];
        final posts = [
          ...(result?.videos ?? const <FeedItem>[]),
          ...(result?.reels ?? const <FeedItem>[]),
        ];

        if (creators.isEmpty && posts.isEmpty) {
          return const _InlineState(
            icon: Icons.search_off,
            title: 'No results',
            subtitle: 'Try another creator name, video title, or reel caption.',
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (creators.isNotEmpty) ...[
              Text('Creators',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ...creators.map((creator) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CreatorResultTile(
                        creator: creator, session: session, feedApi: feedApi),
                  )),
              const SizedBox(height: 8),
            ],
            if (posts.isNotEmpty) ...[
              Text('Videos & reels',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ...posts.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _FeedItemCard(
                        item: item, session: session, feedApi: feedApi),
                  )),
            ],
          ],
        );
      },
    );
  }
}

class _CreatorResultTile extends StatefulWidget {
  const _CreatorResultTile({
    required this.creator,
    required this.session,
    required this.feedApi,
  });

  final CreatorSearchItem creator;
  final AuthSession session;
  final FeedApi feedApi;

  @override
  State<_CreatorResultTile> createState() => _CreatorResultTileState();
}

class _CreatorResultTileState extends State<_CreatorResultTile> {
  bool _isFollowing = false;
  bool _isBusy = false;

  Future<void> _toggleFollow() async {
    if (_isBusy) {
      return;
    }

    setState(() => _isBusy = true);

    try {
      if (_isFollowing) {
        await widget.feedApi.unfollowCreator(
            session: widget.session, creatorId: widget.creator.id);
      } else {
        await widget.feedApi.followCreator(
            session: widget.session, creatorId: widget.creator.id);
      }

      if (mounted) {
        setState(() => _isFollowing = !_isFollowing);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _reportCreator() async {
    await _showReportDialog(
      context: context,
      title: 'Report @${widget.creator.username}',
      onSubmit: (reason) => widget.feedApi.reportCreator(
        session: widget.session,
        creatorId: widget.creator.id,
        reason: reason,
      ),
    );
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreatorProfilePage(
          creatorId: widget.creator.id,
          session: widget.session,
          feedApi: widget.feedApi,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final creator = widget.creator;

    return ListTile(
      onTap: _openProfile,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      leading: CircleAvatar(
        backgroundImage: creator.avatarUrl == null || creator.avatarUrl!.isEmpty
            ? null
            : NetworkImage(creator.avatarUrl!),
        child: creator.avatarUrl == null || creator.avatarUrl!.isEmpty
            ? Text(creator.username.characters.first.toUpperCase())
            : null,
      ),
      title: Text(creator.displayName,
          style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(
          '@${creator.username} • ${creator.followerCount} followers • ${creator.videoCount + creator.reelCount} posts'),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            onPressed: _reportCreator,
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Report creator',
          ),
          TextButton(
            onPressed: _isBusy ? null : _toggleFollow,
            child: Text(_isFollowing ? 'Following' : 'Follow'),
          ),
        ],
      ),
    );
  }
}

class CreatorProfilePage extends StatefulWidget {
  const CreatorProfilePage({
    required this.creatorId,
    required this.session,
    required this.feedApi,
    super.key,
  });

  final String creatorId;
  final AuthSession session;
  final FeedApi feedApi;

  @override
  State<CreatorProfilePage> createState() => _CreatorProfilePageState();
}

class _CreatorProfilePageState extends State<CreatorProfilePage> {
  late Future<CreatorProfile> _profileFuture;
  FeedItemType _selectedType = FeedItemType.video;
  bool _isFollowing = false;
  bool _isLiked = false;
  bool _isBusy = false;
  int? _followerCount;
  int? _likeCount;
  int? _shareCount;

  @override
  void initState() {
    super.initState();
    _profileFuture = widget.feedApi.creatorProfile(widget.creatorId);
  }

  Future<void> _refresh() async {
    final future = widget.feedApi.creatorProfile(widget.creatorId);
    setState(() => _profileFuture = future);
    final profile = await future;
    _syncCounts(profile.creator);
  }

  void _syncCounts(CreatorSearchItem creator) {
    _followerCount ??= creator.followerCount;
    _likeCount ??= creator.likeCount;
    _shareCount ??= creator.shareCount;
  }

  Future<void> _toggleFollow() async {
    if (_isBusy) {
      return;
    }

    setState(() => _isBusy = true);

    try {
      if (_isFollowing) {
        await widget.feedApi.unfollowCreator(
            session: widget.session, creatorId: widget.creatorId);
      } else {
        await widget.feedApi.followCreator(
            session: widget.session, creatorId: widget.creatorId);
      }

      if (mounted) {
        setState(() {
          _isFollowing = !_isFollowing;
          final currentCount = _followerCount ?? 0;
          _followerCount = _isFollowing
              ? currentCount + 1
              : (currentCount - 1).clamp(0, 1 << 31).toInt();
        });
      }
    } catch (error) {
      _showSnack(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _toggleLike() async {
    if (_isBusy) {
      return;
    }

    setState(() => _isBusy = true);

    try {
      await widget.feedApi.toggleCreatorLike(
          session: widget.session, creatorId: widget.creatorId);

      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          final currentCount = _likeCount ?? 0;
          _likeCount = _isLiked
              ? currentCount + 1
              : (currentCount - 1).clamp(0, 1 << 31).toInt();
        });
      }
    } catch (error) {
      _showSnack(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _share(CreatorSearchItem creator) async {
    try {
      await widget.feedApi
          .shareCreator(session: widget.session, creatorId: widget.creatorId);
      await Clipboard.setData(
          ClipboardData(text: 'nimbark://creator/${widget.creatorId}'));

      if (mounted) {
        setState(() => _shareCount = (_shareCount ?? creator.shareCount) + 1);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Creator link copied.')));
      }
    } catch (error) {
      _showSnack(error.toString());
    }
  }

  Future<void> _report(CreatorSearchItem creator) async {
    await _showReportDialog(
      context: context,
      title: 'Report @${creator.username}',
      onSubmit: (reason) => widget.feedApi.reportCreator(
        session: widget.session,
        creatorId: widget.creatorId,
        reason: reason,
      ),
    );
  }

  Future<void> _openDetail(FeedItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FeedDetailPage(
          item: item,
          session: widget.session,
          feedApi: widget.feedApi,
        ),
      ),
    );

    if (mounted) {
      await _refresh();
    }
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CreatorProfile>(
      future: _profileFuture,
      builder: (context, snapshot) {
        final creator = snapshot.data?.creator;

        return Scaffold(
          appBar: AppBar(
            title: Text(creator == null ? 'Creator' : '@${creator.username}'),
            actions: [
              IconButton(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: switch (snapshot.connectionState) {
            ConnectionState.waiting =>
              const Center(child: CircularProgressIndicator()),
            _ when snapshot.hasError => _InlineState(
                icon: Icons.person_off_outlined,
                title: 'Unable to load creator',
                subtitle: snapshot.error.toString(),
                actionLabel: 'Retry',
                onAction: _refresh,
              ),
            _ => _buildProfile(context, snapshot.data!),
          },
        );
      },
    );
  }

  Widget _buildProfile(BuildContext context, CreatorProfile profile) {
    final creator = profile.creator;
    _syncCounts(creator);

    final items =
        _selectedType == FeedItemType.video ? profile.videos : profile.reels;
    final allItems = [
      ...profile.videos,
      ...profile.reels,
    ];
    final canViewAnalytics = widget.session.user.role == 'ADMIN';

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundImage:
                    creator.avatarUrl == null || creator.avatarUrl!.isEmpty
                        ? null
                        : NetworkImage(creator.avatarUrl!),
                child: creator.avatarUrl == null || creator.avatarUrl!.isEmpty
                    ? Text(_initial(creator.username),
                        style: const TextStyle(fontSize: 24))
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(creator.displayName,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text('@${creator.username}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary)),
                    if (creator.bio != null &&
                        creator.bio!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(creator.bio!),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ProfileStat(
                  label: 'Followers',
                  value: _followerCount ?? creator.followerCount),
              _ProfileStat(label: 'Videos', value: creator.videoCount),
              _ProfileStat(label: 'Reels', value: creator.reelCount),
              _ProfileStat(
                  label: 'Likes', value: _likeCount ?? creator.likeCount),
              _ProfileStat(
                  label: 'Shares', value: _shareCount ?? creator.shareCount),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _isBusy ? null : _toggleFollow,
                icon: Icon(_isFollowing
                    ? Icons.check
                    : Icons.person_add_alt_1_outlined),
                label: Text(_isFollowing ? 'Following' : 'Follow'),
              ),
              OutlinedButton.icon(
                onPressed: _isBusy ? null : _toggleLike,
                icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border),
                label: Text('${_likeCount ?? creator.likeCount}'),
              ),
              OutlinedButton.icon(
                onPressed: () => _share(creator),
                icon: const Icon(Icons.ios_share),
                label: Text('${_shareCount ?? creator.shareCount}'),
              ),
              OutlinedButton.icon(
                onPressed: () => _report(creator),
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Report'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (canViewAnalytics && allItems.isNotEmpty) ...[
            _CreatorAnalyticsSection(
              items: allItems,
              onOpen: _openDetail,
            ),
            const SizedBox(height: 18),
          ],
          SegmentedButton<FeedItemType>(
            segments: const [
              ButtonSegment(
                  value: FeedItemType.video,
                  label: Text('Videos'),
                  icon: Icon(Icons.play_circle_outline)),
              ButtonSegment(
                  value: FeedItemType.reel,
                  label: Text('Reels'),
                  icon: Icon(Icons.video_library_outlined)),
            ],
            selected: {_selectedType},
            onSelectionChanged: (selection) =>
                setState(() => _selectedType = selection.first),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            _InlineState(
              icon: _selectedType == FeedItemType.video
                  ? Icons.play_circle_outline
                  : Icons.video_library_outlined,
              title: _selectedType == FeedItemType.video
                  ? 'No videos yet'
                  : 'No reels yet',
              subtitle:
                  'Published ${_selectedType == FeedItemType.video ? 'videos' : 'reels'} from @${creator.username} will appear here.',
            )
          else
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _FeedItemCard(
                      item: item,
                      session: widget.session,
                      feedApi: widget.feedApi),
                )),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class FeedDetailPage extends StatefulWidget {
  const FeedDetailPage({
    required this.item,
    required this.session,
    required this.feedApi,
    super.key,
  });

  final FeedItem item;
  final AuthSession session;
  final FeedApi feedApi;

  @override
  State<FeedDetailPage> createState() => _FeedDetailPageState();
}

class _FeedDetailPageState extends State<FeedDetailPage>
    with WidgetsBindingObserver {
  static final Set<String> _viewedThisSession = {};

  late Future<List<FeedComment>> _commentsFuture;
  late int _likeCount;
  late int _dislikeCount;
  late int _commentCount;
  late int _shareCount;
  late int _viewCount;
  bool _liked = false;
  bool _disliked = false;
  bool _trackedView = false;
  bool _isPlaying = false;
  bool _isAppActive = true;
  bool _isDeleted = false;
  Timer? _viewTimer;
  DateTime? _eligibleSince;

  FeedItem get item => widget.item;
  Duration get _requiredPlayDuration => item.type == FeedItemType.reel
      ? const Duration(seconds: 3)
      : const Duration(seconds: 5);
  String get _sessionViewKey =>
      '${widget.session.user.id}:detail:${item.type.path}:${item.id}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _likeCount = item.likeCount;
    _dislikeCount = item.dislikeCount;
    _commentCount = item.commentCount;
    _shareCount = item.shareCount;
    _viewCount = item.viewCount;
    _commentsFuture = widget.feedApi.comments(item);
    _trackedView = _viewedThisSession.contains(_sessionViewKey);
    _viewTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _evaluateViewEligibility(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _viewTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppActive = state == AppLifecycleState.resumed;
    if (!_isAppActive) {
      _eligibleSince = null;
    }
  }

  void _handlePlayingChanged(bool isPlaying) {
    if (_isPlaying == isPlaying) {
      return;
    }

    setState(() => _isPlaying = isPlaying);
    if (!isPlaying) {
      _eligibleSince = null;
    }
  }

  void _evaluateViewEligibility() {
    if (!mounted || _trackedView || !_isAppActive || !_isPlaying) {
      _eligibleSince = null;
      return;
    }

    final now = DateTime.now();
    _eligibleSince ??= now;

    if (now.difference(_eligibleSince!) >= _requiredPlayDuration) {
      _trackView();
    }
  }

  Future<void> _trackView() async {
    if (_trackedView) {
      return;
    }

    _trackedView = true;
    _viewedThisSession.add(_sessionViewKey);

    try {
      final result = await widget.feedApi.trackView(
        session: widget.session,
        item: item,
      );
      if (mounted) {
        setState(() => _viewCount = result.viewCount);
      }
    } catch (_) {
      _trackedView = false;
      _viewedThisSession.remove(_sessionViewKey);
    }
  }

  Future<void> _refreshComments() async {
    setState(() => _commentsFuture = widget.feedApi.comments(item));
    await _commentsFuture;
  }

  Future<void> _toggleLike() async {
    try {
      await widget.feedApi.toggleLike(session: widget.session, item: item);
      setState(() {
        _liked = !_liked;
        _likeCount += _liked ? 1 : -1;
        if (_liked && _disliked) {
          _disliked = false;
          _dislikeCount = (_dislikeCount - 1).clamp(0, 1 << 31).toInt();
        }
      });
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _toggleDislike() async {
    try {
      await widget.feedApi.toggleDislike(session: widget.session, item: item);
      setState(() {
        _disliked = !_disliked;
        _dislikeCount += _disliked ? 1 : -1;
        if (_disliked && _liked) {
          _liked = false;
          _likeCount = (_likeCount - 1).clamp(0, 1 << 31).toInt();
        }
      });
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _share() async {
    try {
      await widget.feedApi.share(session: widget.session, item: item);
      await Clipboard.setData(
          ClipboardData(text: 'nimbark://${item.type.path}/${item.id}'));

      if (mounted) {
        setState(() => _shareCount += 1);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Post link copied.')));
      }
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _reportPost() async {
    await _showReportDialog(
      context: context,
      title: 'Report ${item.type == FeedItemType.video ? 'video' : 'reel'}',
      onSubmit: (reason) => widget.feedApi.reportPost(
        session: widget.session,
        item: item,
        reason: reason,
      ),
    );
  }

  Future<void> _deletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            'Delete ${item.type == FeedItemType.video ? 'video' : 'reel'}?'),
        content: const Text('This removes the post from the feed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await widget.feedApi.deletePost(session: widget.session, item: item);
      if (mounted) {
        setState(() => _isDeleted = true);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Post deleted.')));
        Navigator.of(context).pop();
      }
    } catch (error) {
      _showError(error);
    }
  }

  void _openCreatorProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreatorProfilePage(
          creatorId: item.creatorId,
          session: widget.session,
          feedApi: widget.feedApi,
        ),
      ),
    );
  }

  void _showError(Object error) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error.toString())));
  }

  @override
  Widget build(BuildContext context) {
    final canDelete = item.creatorId == widget.session.user.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(item.type == FeedItemType.video ? 'Video' : 'Reel'),
        actions: [
          IconButton(
            onPressed: _refreshComments,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isDeleted
          ? const _InlineState(
              icon: Icons.delete_outline,
              title: 'Post deleted',
              subtitle: 'This post is no longer available.',
            )
          : RefreshIndicator(
              onRefresh: _refreshComments,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _FeedVideoPlayer(
                    url: item.mediaUrl,
                    thumbnailUrl: item.thumbnailUrl,
                    onPlayingChanged: _handlePlayingChanged,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900)),
                        if (item.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(item.subtitle),
                        ],
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          children: [
                            InkWell(
                              onTap: _openCreatorProfile,
                              child: Text(
                                '@${item.creatorUsername}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text('$_viewCount views'),
                            Text('$_commentCount comments'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            TextButton.icon(
                              onPressed: _toggleLike,
                              icon: Icon(_liked
                                  ? Icons.thumb_up
                                  : Icons.thumb_up_outlined),
                              label: Text('$_likeCount'),
                            ),
                            TextButton.icon(
                              onPressed: _toggleDislike,
                              icon: Icon(_disliked
                                  ? Icons.thumb_down
                                  : Icons.thumb_down_outlined),
                              label: Text('$_dislikeCount'),
                            ),
                            TextButton.icon(
                              onPressed: _share,
                              icon: const Icon(Icons.ios_share),
                              label: Text('$_shareCount'),
                            ),
                            TextButton.icon(
                              onPressed: _reportPost,
                              icon: const Icon(Icons.flag_outlined),
                              label: const Text('Report'),
                            ),
                            if (canDelete)
                              TextButton.icon(
                                onPressed: _deletePost,
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Delete'),
                              ),
                          ],
                        ),
                        const Divider(height: 28),
                        _InlineCommentsSection(
                          future: _commentsFuture,
                          session: widget.session,
                          feedApi: widget.feedApi,
                          item: item,
                          commentsEnabled: item.commentsEnabled,
                          onCommentAdded: () {
                            setState(() {
                              _commentCount += 1;
                              _commentsFuture = widget.feedApi.comments(item);
                            });
                          },
                          onCommentDeleted: () {
                            setState(() {
                              _commentCount =
                                  (_commentCount - 1).clamp(0, 1 << 31).toInt();
                              _commentsFuture = widget.feedApi.comments(item);
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class CreatorDashboardPage extends StatefulWidget {
  const CreatorDashboardPage({
    required this.session,
    required this.feedApi,
    super.key,
  });

  final AuthSession session;
  final FeedApi feedApi;

  @override
  State<CreatorDashboardPage> createState() => _CreatorDashboardPageState();
}

class _CreatorDashboardPageState extends State<CreatorDashboardPage> {
  late Future<CreatorProfile> _dashboardFuture;
  FeedItemType _selectedType = FeedItemType.video;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = widget.feedApi.creatorProfile(widget.session.user.id);
  }

  Future<void> _refresh() async {
    final future = widget.feedApi.creatorProfile(widget.session.user.id);
    setState(() => _dashboardFuture = future);
    await future;
  }

  Future<void> _deletePost(FeedItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            'Delete ${item.type == FeedItemType.video ? 'video' : 'reel'}?'),
        content: const Text('This removes it from viewer feeds.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await widget.feedApi.deletePost(session: widget.session, item: item);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Post deleted.')));
        await _refresh();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _openDetail(FeedItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FeedDetailPage(
          item: item,
          session: widget.session,
          feedApi: widget.feedApi,
        ),
      ),
    );

    if (mounted) {
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Creator dashboard'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<CreatorProfile>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _InlineState(
              icon: Icons.dashboard_outlined,
              title: 'Unable to load dashboard',
              subtitle: snapshot.error.toString(),
              actionLabel: 'Retry',
              onAction: _refresh,
            );
          }

          final profile = snapshot.data!;
          final items = _selectedType == FeedItemType.video
              ? profile.videos
              : profile.reels;
          final allPosts = profile.videos.length + profile.reels.length;
          final allItems = [
            ...profile.videos,
            ...profile.reels,
          ];
          final totalViews =
              allItems.fold<int>(0, (sum, item) => sum + item.viewCount);
          final totalLikes =
              allItems.fold<int>(0, (sum, item) => sum + item.likeCount);
          final totalComments =
              allItems.fold<int>(0, (sum, item) => sum + item.commentCount);
          final totalShares =
              allItems.fold<int>(0, (sum, item) => sum + item.shareCount);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Your content',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _ProfileStat(label: 'Posts', value: allPosts),
                    _ProfileStat(label: 'Videos', value: profile.videos.length),
                    _ProfileStat(label: 'Reels', value: profile.reels.length),
                    _ProfileStat(label: 'Views', value: totalViews),
                    _ProfileStat(label: 'Likes', value: totalLikes),
                    _ProfileStat(label: 'Comments', value: totalComments),
                    _ProfileStat(label: 'Shares', value: totalShares),
                  ],
                ),
                const SizedBox(height: 18),
                _CreatorAnalyticsSection(
                  items: allItems,
                  onOpen: _openDetail,
                ),
                const SizedBox(height: 18),
                SegmentedButton<FeedItemType>(
                  segments: const [
                    ButtonSegment(
                        value: FeedItemType.video,
                        label: Text('Videos'),
                        icon: Icon(Icons.play_circle_outline)),
                    ButtonSegment(
                        value: FeedItemType.reel,
                        label: Text('Reels'),
                        icon: Icon(Icons.video_library_outlined)),
                  ],
                  selected: {_selectedType},
                  onSelectionChanged: (selection) =>
                      setState(() => _selectedType = selection.first),
                ),
                const SizedBox(height: 14),
                if (items.isEmpty)
                  _InlineState(
                    icon: _selectedType == FeedItemType.video
                        ? Icons.play_circle_outline
                        : Icons.video_library_outlined,
                    title: _selectedType == FeedItemType.video
                        ? 'No videos yet'
                        : 'No reels yet',
                    subtitle: 'Upload content to see it here.',
                  )
                else
                  ...items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _DashboardPostTile(
                          item: item,
                          onOpen: () => _openDetail(item),
                          onDelete: () => _deletePost(item),
                        ),
                      )),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DashboardPostTile extends StatelessWidget {
  const _DashboardPostTile({
    required this.item,
    required this.onOpen,
    required this.onDelete,
  });

  final FeedItem item;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onOpen,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      leading: Icon(item.type == FeedItemType.video
          ? Icons.play_circle_outline
          : Icons.video_library_outlined),
      title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
          '${item.viewCount} views • ${item.likeCount} likes • ${item.commentCount} comments'),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            onPressed: onOpen,
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open',
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }
}

class _CreatorAnalyticsSection extends StatelessWidget {
  const _CreatorAnalyticsSection({
    required this.items,
    required this.onOpen,
  });

  final List<FeedItem> items;
  final Future<void> Function(FeedItem item) onOpen;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final topByViews = _topItems((item) => item.viewCount);
    final topByLikes = _topItems((item) => item.likeCount);
    final topByComments = _topItems((item) => item.commentCount);
    final trend = _recentTrend();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Analytics',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        _TopPostsPanel(
          title: 'Top by views',
          icon: Icons.visibility_outlined,
          items: topByViews,
          valueFor: (item) => '${item.viewCount} views',
          onOpen: onOpen,
        ),
        const SizedBox(height: 10),
        _TopPostsPanel(
          title: 'Top by likes',
          icon: Icons.thumb_up_outlined,
          items: topByLikes,
          valueFor: (item) => '${item.likeCount} likes',
          onOpen: onOpen,
        ),
        const SizedBox(height: 10),
        _TopPostsPanel(
          title: 'Top by comments',
          icon: Icons.mode_comment_outlined,
          items: topByComments,
          valueFor: (item) => '${item.commentCount} comments',
          onOpen: onOpen,
        ),
        const SizedBox(height: 10),
        _TrendPanel(days: trend),
      ],
    );
  }

  List<FeedItem> _topItems(int Function(FeedItem item) valueFor) {
    final sorted = [...items]
      ..sort((a, b) => valueFor(b).compareTo(valueFor(a)));
    return sorted.take(3).toList();
  }

  List<_TrendDay> _recentTrend() {
    final now = DateTime.now();
    return List.generate(7, (index) {
      final day = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: 6 - index));
      final dayItems = items.where((item) {
        final created = item.createdAt.toLocal();
        return created.year == day.year &&
            created.month == day.month &&
            created.day == day.day;
      }).toList();

      return _TrendDay(
        label: '${day.day}/${day.month}',
        posts: dayItems.length,
        views: dayItems.fold<int>(0, (sum, item) => sum + item.viewCount),
        likes: dayItems.fold<int>(0, (sum, item) => sum + item.likeCount),
        comments: dayItems.fold<int>(0, (sum, item) => sum + item.commentCount),
      );
    });
  }
}

class _TopPostsPanel extends StatelessWidget {
  const _TopPostsPanel({
    required this.title,
    required this.icon,
    required this.items,
    required this.valueFor,
    required this.onOpen,
  });

  final String title;
  final IconData icon;
  final List<FeedItem> items;
  final String Function(FeedItem item) valueFor;
  final Future<void> Function(FeedItem item) onOpen;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 8),
            ...items.map((item) {
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                onTap: () => onOpen(item),
                title: Text(item.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle:
                    Text(item.type == FeedItemType.video ? 'Video' : 'Reel'),
                trailing: Text(valueFor(item)),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _TrendPanel extends StatelessWidget {
  const _TrendPanel({required this.days});

  final List<_TrendDay> days;

  @override
  Widget build(BuildContext context) {
    final maxViews = days.fold<int>(
      1,
      (max, day) => day.views > max ? day.views : max,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.trending_up, size: 18),
                const SizedBox(width: 8),
                Text('Last 7 days',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 12),
            ...days.map((day) {
              final widthFactor = day.views / maxViews;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(width: 44, child: Text(day.label)),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: widthFactor == 0 ? 0.02 : widthFactor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 104,
                      child: Text(
                        '${day.views} views',
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 4),
            Text(
              '${days.fold<int>(0, (sum, day) => sum + day.posts)} posts • '
              '${days.fold<int>(0, (sum, day) => sum + day.likes)} likes • '
              '${days.fold<int>(0, (sum, day) => sum + day.comments)} comments',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendDay {
  const _TrendDay({
    required this.label,
    required this.posts,
    required this.views,
    required this.likes,
    required this.comments,
  });

  final String label;
  final int posts;
  final int views;
  final int likes;
  final int comments;
}

class _InlineCommentsSection extends StatefulWidget {
  const _InlineCommentsSection({
    required this.future,
    required this.session,
    required this.feedApi,
    required this.item,
    required this.commentsEnabled,
    required this.onCommentAdded,
    required this.onCommentDeleted,
  });

  final Future<List<FeedComment>> future;
  final AuthSession session;
  final FeedApi feedApi;
  final FeedItem item;
  final bool commentsEnabled;
  final VoidCallback onCommentAdded;
  final VoidCallback onCommentDeleted;

  @override
  State<_InlineCommentsSection> createState() => _InlineCommentsSectionState();
}

class _InlineCommentsSectionState extends State<_InlineCommentsSection> {
  final _controller = TextEditingController();
  final Set<String> _deletingCommentIds = {};
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final body = _controller.text.trim();

    if (body.isEmpty || _isSending) {
      return;
    }

    setState(() => _isSending = true);

    try {
      await widget.feedApi.createComment(
        session: widget.session,
        item: widget.item,
        body: body,
      );
      _controller.clear();
      widget.onCommentAdded();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  bool _canDeleteComment(FeedComment comment) {
    return widget.session.user.role == 'ADMIN' ||
        widget.item.creatorId == widget.session.user.id ||
        comment.authorId == widget.session.user.id;
  }

  Future<void> _deleteComment(FeedComment comment) async {
    if (_deletingCommentIds.contains(comment.id)) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text('This removes the comment from this post.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _deletingCommentIds.add(comment.id));

    try {
      await widget.feedApi.deleteComment(
        session: widget.session,
        item: widget.item,
        comment: comment,
      );
      widget.onCommentDeleted();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Comment deleted.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _deletingCommentIds.remove(comment.id));
      }
    }
  }

  Future<void> _reportComment(FeedComment comment) async {
    await _showReportDialog(
      context: context,
      title: 'Report @${comment.username}',
      onSubmit: (reason) => widget.feedApi.reportComment(
        session: widget.session,
        item: widget.item,
        comment: comment,
        reason: reason,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Comments',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        if (widget.commentsEnabled)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLength: 250,
                  decoration: const InputDecoration(
                    hintText: 'Add a comment',
                    prefixIcon: Icon(Icons.mode_comment_outlined),
                  ),
                  onSubmitted: (_) => _sendComment(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _isSending ? null : _sendComment,
                icon: _isSending
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
              ),
            ],
          )
        else
          const Text('Comments are disabled for this post.'),
        const SizedBox(height: 8),
        FutureBuilder<List<FeedComment>>(
          future: widget.future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return Text(snapshot.error.toString());
            }

            final comments = snapshot.data ?? const [];

            if (comments.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(child: Text('No comments yet.')),
              );
            }

            return Column(
              children: comments.map((comment) {
                final canDelete = _canDeleteComment(comment);
                final canReport = comment.authorId != widget.session.user.id;
                final isDeleting = _deletingCommentIds.contains(comment.id);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('@${comment.username}',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(comment.body),
                  trailing: Wrap(
                    spacing: 2,
                    children: [
                      if (canReport)
                        IconButton(
                          onPressed: () => _reportComment(comment),
                          icon: const Icon(Icons.flag_outlined),
                          tooltip: 'Report comment',
                        ),
                      if (canDelete)
                        IconButton(
                          onPressed:
                              isDeleting ? null : () => _deleteComment(comment),
                          icon: isDeleting
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.delete_outline),
                          tooltip: 'Delete comment',
                        ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _FeedItemCard extends StatefulWidget {
  const _FeedItemCard({
    required this.item,
    required this.session,
    required this.feedApi,
  });

  final FeedItem item;
  final AuthSession session;
  final FeedApi feedApi;

  @override
  State<_FeedItemCard> createState() => _FeedItemCardState();
}

class _FeedItemCardState extends State<_FeedItemCard>
    with WidgetsBindingObserver {
  static final Set<String> _viewedThisSession = {};

  final _cardKey = GlobalKey();
  late int _likeCount;
  late int _dislikeCount;
  late int _commentCount;
  late int _shareCount;
  late int _viewCount;
  bool _liked = false;
  bool _disliked = false;
  bool _trackedView = false;
  bool _isDeleted = false;
  bool _isPlaying = false;
  bool _isAppActive = true;
  Timer? _viewTimer;
  DateTime? _eligibleSince;

  FeedItem get item => widget.item;
  double get _requiredVisibility => item.type == FeedItemType.reel ? 0.7 : 0.5;
  Duration get _requiredPlayDuration => item.type == FeedItemType.reel
      ? const Duration(seconds: 3)
      : const Duration(seconds: 5);
  String get _sessionViewKey =>
      '${widget.session.user.id}:${item.type.path}:${item.id}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _likeCount = item.likeCount;
    _dislikeCount = item.dislikeCount;
    _commentCount = item.commentCount;
    _shareCount = item.shareCount;
    _viewCount = item.viewCount;
    _trackedView = _viewedThisSession.contains(_sessionViewKey);
    _viewTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _evaluateViewEligibility(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _viewTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isActive = state == AppLifecycleState.resumed;
    if (_isAppActive == isActive) {
      return;
    }

    _isAppActive = isActive;
    if (!isActive) {
      _eligibleSince = null;
    }
  }

  void _handlePlayingChanged(bool isPlaying) {
    if (_isPlaying == isPlaying) {
      return;
    }

    setState(() => _isPlaying = isPlaying);
    if (!isPlaying) {
      _eligibleSince = null;
    }
  }

  void _evaluateViewEligibility() {
    if (!mounted ||
        _isDeleted ||
        _trackedView ||
        !_isAppActive ||
        !_isPlaying) {
      _eligibleSince = null;
      return;
    }

    final visibleFraction = _visibleFraction();

    if (visibleFraction < _requiredVisibility) {
      _eligibleSince = null;
      return;
    }

    final now = DateTime.now();
    _eligibleSince ??= now;

    if (now.difference(_eligibleSince!) >= _requiredPlayDuration) {
      _trackView();
    }
  }

  double _visibleFraction() {
    final context = _cardKey.currentContext;

    if (context == null) {
      return 0;
    }

    final renderObject = context.findRenderObject();

    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return 0;
    }

    final topLeft = renderObject.localToGlobal(Offset.zero);
    final size = renderObject.size;
    final screenHeight = MediaQuery.of(context).size.height;
    final top = topLeft.dy.clamp(0.0, screenHeight);
    final bottom = (topLeft.dy + size.height).clamp(0.0, screenHeight);
    final visibleHeight = bottom - top;

    if (visibleHeight <= 0 || size.height <= 0) {
      return 0;
    }

    return (visibleHeight / size.height).clamp(0.0, 1.0);
  }

  Future<void> _trackView() async {
    if (_trackedView) {
      return;
    }

    _trackedView = true;
    _viewedThisSession.add(_sessionViewKey);

    try {
      final result = await widget.feedApi.trackView(
        session: widget.session,
        item: item,
      );
      if (mounted) {
        setState(() => _viewCount = result.viewCount);
      }
    } catch (_) {
      _trackedView = false;
      _viewedThisSession.remove(_sessionViewKey);
    }
  }

  Future<void> _toggleLike() async {
    try {
      await widget.feedApi.toggleLike(session: widget.session, item: item);
      setState(() {
        _liked = !_liked;
        _likeCount += _liked ? 1 : -1;
        if (_liked && _disliked) {
          _disliked = false;
          _dislikeCount = (_dislikeCount - 1).clamp(0, 1 << 31).toInt();
        }
      });
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _toggleDislike() async {
    try {
      await widget.feedApi.toggleDislike(session: widget.session, item: item);
      setState(() {
        _disliked = !_disliked;
        _dislikeCount += _disliked ? 1 : -1;
        if (_disliked && _liked) {
          _liked = false;
          _likeCount = (_likeCount - 1).clamp(0, 1 << 31).toInt();
        }
      });
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _share() async {
    try {
      await widget.feedApi.share(session: widget.session, item: item);
      await Clipboard.setData(
          ClipboardData(text: 'nimbark://${item.type.path}/${item.id}'));
      if (mounted) {
        setState(() => _shareCount += 1);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Post link copied.')));
      }
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _reportPost() async {
    await _showReportDialog(
      context: context,
      title: 'Report ${item.type == FeedItemType.video ? 'video' : 'reel'}',
      onSubmit: (reason) => widget.feedApi.reportPost(
        session: widget.session,
        item: item,
        reason: reason,
      ),
    );
  }

  Future<void> _deletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            'Delete ${item.type == FeedItemType.video ? 'video' : 'reel'}?'),
        content: const Text('This removes the post from the feed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await widget.feedApi.deletePost(session: widget.session, item: item);

      if (mounted) {
        setState(() => _isDeleted = true);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Post deleted.')));
      }
    } catch (error) {
      _showError(error);
    }
  }

  void _openCreatorProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreatorProfilePage(
          creatorId: item.creatorId,
          session: widget.session,
          feedApi: widget.feedApi,
        ),
      ),
    );
  }

  Future<void> _openDetail() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FeedDetailPage(
          item: item,
          session: widget.session,
          feedApi: widget.feedApi,
        ),
      ),
    );
  }

  Future<void> _showComments() async {
    final controller = TextEditingController();
    final commentsFuture = widget.feedApi.comments(item);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> sendComment() async {
              final body = controller.text.trim();

              if (body.isEmpty) {
                return;
              }

              try {
                await widget.feedApi.createComment(
                    session: widget.session, item: item, body: body);
                controller.clear();
                if (mounted) {
                  setState(() => _commentCount += 1);
                }
                if (!context.mounted) {
                  return;
                }
                Navigator.of(context).pop();
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(error.toString())));
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.55,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Comments',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    Expanded(
                      child: FutureBuilder<List<FeedComment>>(
                        future: commentsFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          final comments = snapshot.data ?? const [];

                          if (comments.isEmpty) {
                            return const Center(
                                child: Text('No comments yet.'));
                          }

                          return ListView.separated(
                            itemCount: comments.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final comment = comments[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text('@${comment.username}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800)),
                                subtitle: Text(comment.body),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    if (item.commentsEnabled) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controller,
                              decoration: const InputDecoration(
                                  hintText: 'Add a comment'),
                              maxLength: 250,
                              onSubmitted: (_) => sendComment(),
                            ),
                          ),
                          IconButton(
                            onPressed: sendComment,
                            icon: const Icon(Icons.send),
                          ),
                        ],
                      ),
                    ] else
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text('Comments are disabled for this post.'),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    controller.dispose();
  }

  void _showError(Object error) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error.toString())));
  }

  @override
  Widget build(BuildContext context) {
    if (_isDeleted) {
      return const SizedBox.shrink();
    }

    final canDelete = item.creatorId == widget.session.user.id;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      key: _cardKey,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
            child: Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _openCreatorProfile,
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Text(
                      _initial(item.creatorUsername),
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _openCreatorProfile,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '@${item.creatorUsername}',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.type == FeedItemType.video ? 'Video' : 'Reel',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Post actions',
                  onSelected: (value) {
                    if (value == 'open') {
                      _openDetail();
                    } else if (value == 'report') {
                      _reportPost();
                    } else if (value == 'delete') {
                      _deletePost();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'open', child: Text('Open')),
                    const PopupMenuItem(value: 'report', child: Text('Report')),
                    if (canDelete)
                      const PopupMenuItem(
                          value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
          ),
          _FeedVideoPlayer(
            url: item.mediaUrl,
            thumbnailUrl: item.thumbnailUrl,
            onPlayingChanged: _handlePlayingChanged,
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _openDetail,
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                if (item.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.subtitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetaPill(
                      icon: Icons.visibility_outlined,
                      label: '$_viewCount views',
                    ),
                    _MetaPill(
                      icon: Icons.mode_comment_outlined,
                      label: '$_commentCount comments',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PostActionButton(
                      icon: _liked ? Icons.thumb_up : Icons.thumb_up_outlined,
                      label: '$_likeCount',
                      isActive: _liked,
                      onTap: _toggleLike,
                    ),
                    _PostActionButton(
                      icon: _disliked
                          ? Icons.thumb_down
                          : Icons.thumb_down_outlined,
                      label: '$_dislikeCount',
                      isActive: _disliked,
                      onTap: _toggleDislike,
                    ),
                    _PostActionButton(
                      icon: Icons.mode_comment_outlined,
                      label: 'Comment',
                      onTap: _showComments,
                    ),
                    _PostActionButton(
                      icon: Icons.ios_share,
                      label: 'Share',
                      onTap: _share,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedVideoPlayer extends StatefulWidget {
  const _FeedVideoPlayer({
    required this.url,
    this.thumbnailUrl,
    this.onPlayingChanged,
  });

  final String url;
  final String? thumbnailUrl;
  final ValueChanged<bool>? onPlayingChanged;

  @override
  State<_FeedVideoPlayer> createState() => _FeedVideoPlayerState();
}

class _FeedVideoPlayerState extends State<_FeedVideoPlayer> {
  late final VideoPlayerController _controller;
  late final Future<void> _initializeFuture;
  bool _lastPlayingState = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _initializeFuture = _controller.initialize();
    _controller.setLooping(true);
    _controller.addListener(_notifyPlayingChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_notifyPlayingChanged);
    widget.onPlayingChanged?.call(false);
    _controller.dispose();
    super.dispose();
  }

  void _notifyPlayingChanged() {
    final isPlaying = _controller.value.isPlaying;

    if (_lastPlayingState == isPlaying) {
      return;
    }

    _lastPlayingState = isPlaying;
    widget.onPlayingChanged?.call(isPlaying);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return AspectRatio(
            aspectRatio: 16 / 9,
            child: _VideoThumbnailPlaceholder(
              thumbnailUrl: widget.thumbnailUrl,
              child: const CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return const AspectRatio(
            aspectRatio: 16 / 9,
            child: Center(child: Icon(Icons.broken_image_outlined)),
          );
        }

        return GestureDetector(
          onTap: () {
            setState(() {
              _controller.value.isPlaying
                  ? _controller.pause()
                  : _controller.play();
            });
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: _controller.value.aspectRatio == 0
                    ? 16 / 9
                    : _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
              if (!_controller.value.isPlaying)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: _themeAlpha(Colors.black, 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child:
                        Icon(Icons.play_arrow, color: Colors.white, size: 34),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _VideoThumbnailPlaceholder extends StatelessWidget {
  const _VideoThumbnailPlaceholder({
    required this.child,
    this.thumbnailUrl,
  });

  final Widget child;
  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    final url = thumbnailUrl;

    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        if (url != null && url.isNotEmpty)
          Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(
              color: Colors.black12,
            ),
          )
        else
          const ColoredBox(color: Colors.black12),
        ColoredBox(color: _themeAlpha(Colors.black, 0.28)),
        Center(child: child),
      ],
    );
  }
}

class _InlineState extends StatelessWidget {
  const _InlineState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _SurfacePanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 30, color: colorScheme.primary),
              ),
              const SizedBox(height: 12),
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 14),
                OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _formatUploadDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _initial(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
}

Future<void> _showReportDialog({
  required BuildContext context,
  required String title,
  required Future<void> Function(String reason) onSubmit,
}) async {
  final controller = TextEditingController();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      var isSubmitting = false;

      return StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> submit() async {
            final reason = controller.text.trim();

            if (reason.isEmpty || isSubmitting) {
              return;
            }

            setDialogState(() => isSubmitting = true);

            try {
              await onSubmit(reason);

              if (!context.mounted) {
                return;
              }

              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report submitted.')));
            } catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(error.toString())));
              }
            } finally {
              if (context.mounted) {
                setDialogState(() => isSubmitting = false);
              }
            }
          }

          return AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Reason'),
              maxLength: 500,
              minLines: 3,
              maxLines: 5,
            ),
            actions: [
              TextButton(
                onPressed:
                    isSubmitting ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isSubmitting ? null : submit,
                child: Text(isSubmitting ? 'Submitting' : 'Submit'),
              ),
            ],
          );
        },
      );
    },
  );

  controller.dispose();
}

class LivePage extends StatefulWidget {
  const LivePage({
    required this.session,
    super.key,
  });

  final AuthSession session;

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {
  static const _goLiveTimeout = Duration(seconds: 15);
  static const _retryDelay = Duration(seconds: 2);

  final _liveApi = LiveApi(apiBaseUrl: AppConfig.apiBaseUrl);
  final _titleController = TextEditingController(text: 'Live from Nimbark');

  late Future<List<LiveRoom>> _roomsFuture;
  bool _isCreating = false;

  bool get _canGoLive =>
      widget.session.user.role == 'CREATOR' ||
      widget.session.user.role == 'ADMIN';

  @override
  void initState() {
    super.initState();
    _roomsFuture = _liveApi.liveRooms();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _refreshRooms() {
    setState(() {
      _roomsFuture = _liveApi.liveRooms();
    });
  }

  Future<void> _goLive() async {
    setState(() => _isCreating = true);

    LiveRoom? room;

    try {
      final title = _titleController.text.trim().isEmpty
          ? 'Untitled live'
          : _titleController.text.trim();
      final joinToken = await _retryGoLiveAction(() async {
        room = await _liveApi
            .createRoom(
              session: widget.session,
              title: title,
            )
            .timeout(_goLiveTimeout);
        await _liveApi
            .startRoom(session: widget.session, roomId: room!.id)
            .timeout(_goLiveTimeout);
        return _liveApi
            .createToken(
              session: widget.session,
              roomId: room!.id,
            )
            .timeout(_goLiveTimeout);
      });
      await _openLiveRoom(joinToken);
      _refreshRooms();
    } catch (error) {
      final failedRoom = room;

      if (failedRoom != null) {
        await _endFailedLiveSession(failedRoom.id);
      }

      _showMessage(_friendlyLiveError(error));
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  Future<T> _retryGoLiveAction<T>(Future<T> Function() action) async {
    Object? lastError;

    for (var attempt = 1; attempt <= 2; attempt += 1) {
      try {
        return await action();
      } catch (error) {
        lastError = error;

        if (attempt == 2) {
          break;
        }

        await Future<void>.delayed(_retryDelay);
      }
    }

    throw lastError ?? TimeoutException('Unable to start live session');
  }

  Future<void> _endFailedLiveSession(String roomId) async {
    try {
      await _liveApi
          .endRoom(
            session: widget.session,
            roomId: roomId,
          )
          .timeout(_goLiveTimeout);
    } catch (_) {
      // Best effort cleanup. The user-facing error should stay focused on why going live failed.
    }
  }

  Future<void> _joinRoom(LiveRoom room) async {
    try {
      final joinToken = await _liveApi
          .createToken(
            session: widget.session,
            roomId: room.id,
          )
          .timeout(_goLiveTimeout);
      await _openLiveRoom(joinToken);
    } catch (error) {
      _showMessage(_friendlyLiveError(error));
    }
  }

  Future<void> _openLiveRoom(LiveJoinToken joinToken) async {
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveKitRoomPage(
          session: widget.session,
          liveApi: _liveApi,
          joinToken: joinToken,
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => _refreshRooms(),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Live', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              _canGoLive
                  ? 'Create a live room or join sessions already running.'
                  : 'Join ongoing live sessions from creators.',
            ),
            const SizedBox(height: 24),
            if (_canGoLive) ...[
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Live title',
                  prefixIcon: Icon(Icons.title),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _isCreating ? null : _goLive,
                icon: _isCreating
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sensors),
                label: const Text('Go live'),
              ),
              const SizedBox(height: 28),
            ],
            Row(
              children: [
                Expanded(
                  child: Text('Ongoing live',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                IconButton(
                  onPressed: _refreshRooms,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<LiveRoom>>(
              future: _roomsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return Text(snapshot.error.toString());
                }

                final rooms = snapshot.data ?? const [];

                if (rooms.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('No one is live right now.'),
                  );
                }

                return Column(
                  children: rooms.map((room) {
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.sensors),
                        title: Text(room.title),
                        subtitle: Text(room.hostName == null
                            ? room.status
                            : '${room.hostName} • ${room.status}'),
                        trailing: FilledButton(
                          onPressed: () => _joinRoom(room),
                          child: const Text('Join'),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

String _friendlyLiveError(Object error) {
  if (error is TimeoutException) {
    return 'Live connection timed out. Please check your internet and try again.';
  }

  final message = error.toString();

  if (message.contains('TimeoutException')) {
    return 'Live connection timed out. Please check your internet and try again.';
  }

  return message;
}

class LiveKitRoomPage extends StatefulWidget {
  const LiveKitRoomPage({
    required this.session,
    required this.liveApi,
    required this.joinToken,
    super.key,
  });

  final AuthSession session;
  final LiveApi liveApi;
  final LiveJoinToken joinToken;

  @override
  State<LiveKitRoomPage> createState() => _LiveKitRoomPageState();
}

class _LiveKitRoomPageState extends State<LiveKitRoomPage> {
  static const _connectTimeout = Duration(seconds: 20);
  static const _retryDelay = Duration(seconds: 2);
  static const _liveDataTopic = 'nimbark.live';

  final lk.Room _room = lk.Room(
    roomOptions: const lk.RoomOptions(
      adaptiveStream: true,
      dynacast: true,
    ),
  );
  final _commentController = TextEditingController();

  late final lk.EventsListener<lk.RoomEvent> _listener;

  lk.VideoTrack? _primaryVideoTrack;
  Timer? _liveTimer;
  Timer? _interactionTimer;
  Timer? _presenceTimer;
  List<LiveComment> _comments = const [];
  List<LiveReactionCount> _reactions = const [];
  List<String> _ownReactions = const [];
  List<_LiveViewer> _activeViewers = const [];
  List<LiveBlockedViewer> _blockedViewers = const [];
  Set<String> _blockingViewerIds = const {};
  Set<String> _unblockingViewerIds = const {};
  Duration _liveDuration = Duration.zero;
  int _viewerCount = 0;
  late bool _commentsOn;
  late bool _reactionsOn;
  bool _isConnecting = true;
  bool _isCameraEnabled = false;
  bool _isMicrophoneEnabled = false;
  bool _isLeaving = false;
  bool _sessionEndedAfterFailure = false;
  bool _isSendingComment = false;
  bool _showCommentsPanel = true;
  bool _showViewersPanel = false;
  bool _viewerPresenceRecorded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _commentsOn = widget.joinToken.commentsOn;
    _reactionsOn = widget.joinToken.reactionsOn;
    _listener = _room.createListener()
      ..on<lk.TrackSubscribedEvent>((event) {
        if (event.track is lk.VideoTrack) {
          _selectPrimaryVideoTrack();
        }
      })
      ..on<lk.DataReceivedEvent>(_handleLiveDataEvent)
      ..on<lk.RoomDisconnectedEvent>((event) {
        if (!_isLeaving && !widget.joinToken.canPublish && mounted) {
          setState(() => _error =
              'You were removed from this live room or the live has ended.');
        }
      })
      ..on<lk.TrackUnsubscribedEvent>((event) => _selectPrimaryVideoTrack())
      ..on<lk.ParticipantConnectedEvent>((event) {
        _syncViewerState();
        _selectPrimaryVideoTrack();
      })
      ..on<lk.ParticipantDisconnectedEvent>((event) {
        _syncViewerState();
        _selectPrimaryVideoTrack();
      });
    _syncLiveDuration();
    if (widget.joinToken.canPublish) {
      _liveTimer = Timer.periodic(
          const Duration(seconds: 1), (_) => _syncLiveDuration());
      unawaited(_refreshBlockedViewers(silent: true));
    }
    _refreshInteractions();
    _interactionTimer = Timer.periodic(
        const Duration(seconds: 4), (_) => _refreshInteractions(silent: true));
    _connect();
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _interactionTimer?.cancel();
    _presenceTimer?.cancel();
    _commentController.dispose();
    _listener.dispose();
    unawaited(_room.disconnect());
    unawaited(_room.dispose());
    super.dispose();
  }

  void _syncLiveDuration() {
    final startedAt = widget.joinToken.startedAt;

    if (startedAt == null) {
      return;
    }

    final duration = DateTime.now().difference(startedAt.toLocal());
    final nextDuration = duration.isNegative ? Duration.zero : duration;

    if (mounted) {
      setState(() => _liveDuration = nextDuration);
    } else {
      _liveDuration = nextDuration;
    }
  }

  Future<void> _connect() async {
    setState(() {
      _isConnecting = true;
      _error = null;
    });

    try {
      await _connectWithRetry();
      try {
        await _markViewerJoined();
        _startViewerPresenceHeartbeat();
      } catch (_) {
        // Joining the room should not fail just because analytics could not be recorded.
      }
      _syncViewerState();
      _selectPrimaryVideoTrack();
    } catch (error) {
      if (widget.joinToken.canPublish) {
        await _endFailedHostSession();
      }

      if (!mounted) {
        return;
      }

      setState(() => _error = widget.joinToken.canPublish &&
              _sessionEndedAfterFailure
          ? '${_friendlyLiveError(error)} The live session was ended, so it will not stay active in admin.'
          : _friendlyLiveError(error));
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  Future<void> _connectWithRetry() async {
    Object? lastError;

    for (var attempt = 1; attempt <= 2; attempt += 1) {
      try {
        if (widget.joinToken.canPublish) {
          await _requestMediaPermissions().timeout(_connectTimeout);
        }

        await _room
            .connect(widget.joinToken.wsUrl, widget.joinToken.token)
            .timeout(_connectTimeout);

        if (widget.joinToken.canPublish) {
          await _room.localParticipant
              ?.setCameraEnabled(true)
              .timeout(_connectTimeout);
          await _room.localParticipant
              ?.setMicrophoneEnabled(true)
              .timeout(_connectTimeout);
          _isCameraEnabled = true;
          _isMicrophoneEnabled = true;
        }

        return;
      } catch (error) {
        lastError = error;
        await _room.disconnect();

        if (attempt == 2 || !mounted) {
          break;
        }

        setState(() => _error = 'Connection failed. Retrying...');
        await Future<void>.delayed(_retryDelay);
      }
    }

    throw lastError ?? TimeoutException('Live connection timed out');
  }

  Future<void> _endFailedHostSession() async {
    try {
      await widget.liveApi
          .endRoom(
            session: widget.session,
            roomId: widget.joinToken.roomId,
          )
          .timeout(_connectTimeout);
      _sessionEndedAfterFailure = true;
    } catch (_) {
      _sessionEndedAfterFailure = false;
    }
  }

  Future<void> _requestMediaPermissions() async {
    final permissions = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    final cameraGranted = permissions[Permission.camera]?.isGranted ?? false;
    final microphoneGranted =
        permissions[Permission.microphone]?.isGranted ?? false;

    if (!cameraGranted || !microphoneGranted) {
      throw Exception(
          'Camera and microphone permission are required to go live');
    }
  }

  void _syncViewerState() {
    final viewers = _room.remoteParticipants.values
        .where((participant) => participant.identity.endsWith(':viewer'))
        .map(_viewerFromParticipant)
        .toList()
      ..sort((left, right) => left.username.compareTo(right.username));
    final viewerCount = viewers.length;

    if (mounted) {
      setState(() {
        _activeViewers = viewers;
        _viewerCount = viewerCount;
      });
    } else {
      _activeViewers = viewers;
      _viewerCount = viewerCount;
    }
  }

  _LiveViewer _viewerFromParticipant(lk.RemoteParticipant participant) {
    final identityParts = participant.identity.split(':');
    final userId =
        identityParts.isEmpty ? participant.identity : identityParts.first;
    final name = participant.name.trim();
    final username = name.isEmpty
        ? 'viewer-${userId.substring(0, userId.length < 6 ? userId.length : 6)}'
        : name;

    return _LiveViewer(
      userId: userId,
      identity: participant.identity,
      username: username,
    );
  }

  void _selectPrimaryVideoTrack() {
    lk.VideoTrack? videoTrack;

    final localVideoTrack = _room.localParticipant?.videoTrackPublications
        .map((publication) => publication.track)
        .whereType<lk.VideoTrack>()
        .firstOrNull;

    if (widget.joinToken.canPublish && localVideoTrack != null) {
      videoTrack = localVideoTrack;
    } else {
      for (final participant in _room.remoteParticipants.values) {
        final remoteVideoTrack = participant.videoTrackPublications
            .map((publication) => publication.track)
            .whereType<lk.VideoTrack>()
            .firstOrNull;

        if (remoteVideoTrack != null) {
          videoTrack = remoteVideoTrack;
          break;
        }
      }

      videoTrack ??= localVideoTrack;
    }

    if (mounted) {
      setState(() => _primaryVideoTrack = videoTrack);
    }
  }

  Future<void> _toggleCamera() async {
    final enabled = !_isCameraEnabled;
    await _room.localParticipant?.setCameraEnabled(enabled);
    setState(() => _isCameraEnabled = enabled);
    _selectPrimaryVideoTrack();
  }

  Future<void> _toggleMicrophone() async {
    final enabled = !_isMicrophoneEnabled;
    await _room.localParticipant?.setMicrophoneEnabled(enabled);
    setState(() => _isMicrophoneEnabled = enabled);
  }

  Future<void> _refreshInteractions({bool silent = false}) async {
    try {
      final results = await Future.wait([
        widget.liveApi.comments(
          session: widget.session,
          roomId: widget.joinToken.roomId,
        ),
        widget.liveApi.reactions(
          session: widget.session,
          roomId: widget.joinToken.roomId,
        ),
        widget.liveApi.settings(
          session: widget.session,
          roomId: widget.joinToken.roomId,
        ),
      ]);
      final settings = results[2] as LiveRoomSettings;

      if (!mounted) {
        return;
      }

      setState(() {
        _comments = results[0] as List<LiveComment>;
        _reactions = results[1] as List<LiveReactionCount>;
        _commentsOn = settings.commentsOn;
        _reactionsOn = settings.reactionsOn;
      });
    } catch (error) {
      if (!silent && mounted) {
        setState(() => _error = _friendlyLiveError(error));
      }
    }
  }

  Future<void> _refreshBlockedViewers({bool silent = false}) async {
    if (!widget.joinToken.canPublish) {
      return;
    }

    try {
      final blockedViewers = await widget.liveApi.blockedViewers(
        session: widget.session,
        roomId: widget.joinToken.roomId,
      );

      if (mounted) {
        setState(() => _blockedViewers = blockedViewers);
      }
    } catch (error) {
      if (!silent && mounted) {
        setState(() => _error = _friendlyLiveError(error));
      }
    }
  }

  Future<void> _markViewerJoined() async {
    if (widget.joinToken.canPublish) {
      return;
    }

    await widget.liveApi.viewerJoined(
      session: widget.session,
      roomId: widget.joinToken.roomId,
    );
    _viewerPresenceRecorded = true;
  }

  void _startViewerPresenceHeartbeat() {
    if (widget.joinToken.canPublish || _presenceTimer != null) {
      return;
    }

    _presenceTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_sendViewerPresenceHeartbeat());
    });
  }

  Future<void> _sendViewerPresenceHeartbeat() async {
    try {
      await _markViewerJoined();
    } catch (_) {
      // Heartbeats are best-effort; stale sessions are reconciled on the backend.
    }
  }

  Future<void> _markViewerLeft() async {
    if (widget.joinToken.canPublish || !_viewerPresenceRecorded) {
      return;
    }

    _viewerPresenceRecorded = false;
    _presenceTimer?.cancel();
    _presenceTimer = null;
    await widget.liveApi.viewerLeft(
      session: widget.session,
      roomId: widget.joinToken.roomId,
    );
  }

  Future<void> _sendComment() async {
    final body = _commentController.text.trim();

    if (body.isEmpty || _isSendingComment) {
      return;
    }

    setState(() => _isSendingComment = true);

    try {
      final comment = await widget.liveApi.createComment(
        session: widget.session,
        roomId: widget.joinToken.roomId,
        body: body,
      );

      if (!mounted) {
        return;
      }

      _commentController.clear();
      setState(() => _appendComment(comment));
      unawaited(_publishLiveEvent(
        {
          'type': 'comment',
          'comment': comment.toJson(),
        },
        destinationIdentities: widget.joinToken.canPublish
            ? null
            : [widget.joinToken.hostIdentity],
      ));
    } catch (error) {
      if (mounted) {
        setState(() => _error = _friendlyLiveError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingComment = false);
      }
    }
  }

  Future<void> _sendReaction(String emoji) async {
    try {
      final reactions = await widget.liveApi.createReaction(
        session: widget.session,
        roomId: widget.joinToken.roomId,
        emoji: emoji,
      );

      if (mounted) {
        setState(() {
          _reactions = reactions;
          _appendOwnReaction(emoji);
        });
        unawaited(_publishLiveEvent(
          {
            'type': 'reaction',
            'emoji': emoji,
          },
          destinationIdentities: widget.joinToken.canPublish
              ? null
              : [widget.joinToken.hostIdentity],
        ));
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = _friendlyLiveError(error));
      }
    }
  }

  Future<void> _toggleComments() async {
    final enabled = !_commentsOn;
    setState(() => _commentsOn = enabled);

    try {
      final settings = await widget.liveApi.updateSettings(
        session: widget.session,
        roomId: widget.joinToken.roomId,
        commentsOn: enabled,
      );

      if (mounted) {
        setState(() => _commentsOn = settings.commentsOn);
        unawaited(_publishLiveEvent({
          'type': 'settings',
          'commentsOn': settings.commentsOn,
          'reactionsOn': _reactionsOn,
        }));
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _commentsOn = !enabled;
          _error = _friendlyLiveError(error);
        });
      }
    }
  }

  Future<void> _toggleReactions() async {
    final enabled = !_reactionsOn;
    setState(() => _reactionsOn = enabled);

    try {
      final settings = await widget.liveApi.updateSettings(
        session: widget.session,
        roomId: widget.joinToken.roomId,
        reactionsOn: enabled,
      );

      if (mounted) {
        setState(() => _reactionsOn = settings.reactionsOn);
        unawaited(_publishLiveEvent({
          'type': 'settings',
          'commentsOn': _commentsOn,
          'reactionsOn': settings.reactionsOn,
        }));
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _reactionsOn = !enabled;
          _error = _friendlyLiveError(error);
        });
      }
    }
  }

  Future<void> _blockViewer(_LiveViewer viewer) async {
    if (_blockingViewerIds.contains(viewer.userId)) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Block @${viewer.username}?'),
          content: const Text(
              'This viewer will be removed from the live room and cannot rejoin until unblocked.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Block'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _blockingViewerIds = {..._blockingViewerIds, viewer.userId});

    try {
      await widget.liveApi.blockViewer(
        session: widget.session,
        roomId: widget.joinToken.roomId,
        userId: viewer.userId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _activeViewers = _activeViewers
            .where((activeViewer) => activeViewer.userId != viewer.userId)
            .toList();
        _blockedViewers = [
          LiveBlockedViewer(
            userId: viewer.userId,
            username: viewer.username,
            displayName: viewer.username,
          ),
          ..._blockedViewers
              .where((blockedViewer) => blockedViewer.userId != viewer.userId),
        ];
        _viewerCount = _activeViewers.length;
      });
      unawaited(_publishLiveEvent(
        {
          'type': 'blocked',
          'userId': viewer.userId,
        },
        destinationIdentities: [viewer.identity],
      ));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('@${viewer.username} was blocked from this live')),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = _friendlyLiveError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _blockingViewerIds = _blockingViewerIds
            .where((userId) => userId != viewer.userId)
            .toSet());
      }
    }
  }

  Future<void> _unblockViewer(LiveBlockedViewer viewer) async {
    if (_unblockingViewerIds.contains(viewer.userId)) {
      return;
    }

    setState(
        () => _unblockingViewerIds = {..._unblockingViewerIds, viewer.userId});

    try {
      await widget.liveApi.unblockViewer(
        session: widget.session,
        roomId: widget.joinToken.roomId,
        userId: viewer.userId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _blockedViewers = _blockedViewers
            .where((blockedViewer) => blockedViewer.userId != viewer.userId)
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('@${viewer.username} can join this live again')),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = _friendlyLiveError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _unblockingViewerIds = _unblockingViewerIds
            .where((userId) => userId != viewer.userId)
            .toSet());
      }
    }
  }

  Future<void> _publishLiveEvent(
    Map<String, dynamic> event, {
    List<String>? destinationIdentities,
  }) async {
    final participant = _room.localParticipant;

    if (participant == null) {
      return;
    }

    await participant.publishData(
      utf8.encode(jsonEncode(event)),
      reliable: true,
      topic: _liveDataTopic,
      destinationIdentities: destinationIdentities,
    );
  }

  void _handleLiveDataEvent(lk.DataReceivedEvent event) {
    if (event.topic != _liveDataTopic) {
      return;
    }

    try {
      final payload =
          jsonDecode(utf8.decode(event.data)) as Map<String, dynamic>;
      final type = payload['type'] as String?;

      if (type == 'comment' && widget.joinToken.canPublish) {
        final commentJson = payload['comment'] as Map<String, dynamic>;
        final comment = LiveComment.fromRealtimeJson(commentJson);
        setState(() => _appendComment(comment));
      }

      if (type == 'reaction' && widget.joinToken.canPublish) {
        final emoji = payload['emoji'] as String?;

        if (emoji != null) {
          setState(() => _incrementReaction(emoji));
        }
      }

      if (type == 'settings' && !widget.joinToken.canPublish) {
        setState(() {
          _commentsOn = payload['commentsOn'] as bool? ?? _commentsOn;
          _reactionsOn = payload['reactionsOn'] as bool? ?? _reactionsOn;
        });
      }

      if (type == 'blocked' &&
          !widget.joinToken.canPublish &&
          payload['userId'] == widget.session.user.id) {
        unawaited(_handleBlockedFromLive());
      }
    } catch (_) {
      // Ignore malformed realtime packets; REST polling still reconciles state.
    }
  }

  Future<void> _handleBlockedFromLive() async {
    if (_isLeaving) {
      return;
    }

    _isLeaving = true;
    try {
      await _markViewerLeft();
    } catch (_) {
      // The backend block path also reconciles viewer analytics.
    }
    await _room.disconnect();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You were blocked from this live room')),
      );
      Navigator.of(context).pop();
    }
  }

  void _appendComment(LiveComment comment) {
    final existingIndex = _comments
        .indexWhere((currentComment) => currentComment.id == comment.id);

    if (existingIndex >= 0) {
      _comments = [
        ..._comments.take(existingIndex),
        comment,
        ..._comments.skip(existingIndex + 1),
      ];
      return;
    }

    _comments = [..._comments, comment];
  }

  void _incrementReaction(String emoji) {
    final existingIndex =
        _reactions.indexWhere((reaction) => reaction.emoji == emoji);

    if (existingIndex < 0) {
      _reactions = [..._reactions, LiveReactionCount(emoji: emoji, count: 1)];
      return;
    }

    final currentReaction = _reactions[existingIndex];
    _reactions = [
      ..._reactions.take(existingIndex),
      LiveReactionCount(emoji: emoji, count: currentReaction.count + 1),
      ..._reactions.skip(existingIndex + 1),
    ];
  }

  void _appendOwnReaction(String emoji) {
    final nextReactions = [..._ownReactions, emoji];
    _ownReactions = nextReactions.length > 5
        ? nextReactions.sublist(nextReactions.length - 5)
        : nextReactions;
  }

  Future<void> _leaveRoom() async {
    if (_isLeaving) {
      return;
    }

    setState(() => _isLeaving = true);

    if (widget.joinToken.canPublish) {
      try {
        await widget.liveApi.endRoom(
          session: widget.session,
          roomId: widget.joinToken.roomId,
        );
      } catch (_) {
        // Leaving the LiveKit room should still work even if the app API cannot mark it ended.
      }
    } else {
      try {
        await _markViewerLeft();
      } catch (_) {
        // Leaving the LiveKit room should still work even if analytics cannot be updated.
      }
    }

    await _room.disconnect();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _reportLiveRoom() async {
    await _showReportDialog(
      context: context,
      title: 'Report live stream',
      onSubmit: (reason) => widget.liveApi.reportRoom(
        session: widget.session,
        roomId: widget.joinToken.roomId,
        reason: reason,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final videoTrack = _primaryVideoTrack;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final visibleComments = widget.joinToken.canPublish
        ? _comments
        : _comments
            .where((comment) => comment.userId == widget.session.user.id)
            .toList();
    final commentsBottomOffset = widget.joinToken.canPublish
        ? 92.0
        : (_commentsOn ? 76.0 : 16.0) + bottomInset;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          unawaited(_leaveRoom());
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(widget.joinToken.title),
          actions: [
            if (!widget.joinToken.canPublish)
              IconButton(
                onPressed: _reportLiveRoom,
                icon: const Icon(Icons.flag_outlined),
                tooltip: 'Report live',
              ),
            TextButton.icon(
              onPressed: _isLeaving ? null : _leaveRoom,
              icon: const Icon(Icons.call_end, color: Colors.white),
              label: Text(_isLeaving ? 'Leaving' : 'Leave',
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: videoTrack == null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _isConnecting
                                ? 'Connecting to live room...'
                                : _error ??
                                    'Waiting for live video from ${widget.joinToken.hostName}',
                            style: const TextStyle(color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : lk.VideoTrackRenderer(
                        videoTrack,
                        fit: lk.VideoViewFit.cover,
                      ),
              ),
              if (_error != null)
                Positioned(
                  left: 16,
                  right: 16,
                  top: 16,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              if (widget.joinToken.canPublish)
                Positioned(
                  left: 16,
                  top: _error == null ? 16 : 92,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: _themeAlpha(Colors.black, 0.64),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.timer_outlined,
                                  color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                _formatLiveDuration(_liveDuration),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Icon(Icons.visibility_outlined,
                                  color: Colors.white, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                '$_viewerCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (widget.joinToken.recordingOn) ...[
                                const SizedBox(width: 12),
                                const Icon(Icons.fiber_manual_record,
                                    color: Colors.redAccent, size: 16),
                                const SizedBox(width: 6),
                                const Text(
                                  'REC',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: _themeAlpha(Colors.black, 0.64),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: _toggleComments,
                                color: Colors.white,
                                tooltip: _commentsOn
                                    ? 'Disable comments'
                                    : 'Enable comments',
                                icon: Icon(_commentsOn
                                    ? Icons.chat_bubble_outline
                                    : Icons.comments_disabled_outlined),
                              ),
                              IconButton(
                                onPressed: _toggleReactions,
                                color: Colors.white,
                                tooltip: _reactionsOn
                                    ? 'Disable reactions'
                                    : 'Enable reactions',
                                icon: Icon(_reactionsOn
                                    ? Icons.favorite_border
                                    : Icons.heart_broken_outlined),
                              ),
                              IconButton(
                                onPressed: () => setState(() =>
                                    _showViewersPanel = !_showViewersPanel),
                                color: Colors.white,
                                tooltip: _showViewersPanel
                                    ? 'Hide viewers'
                                    : 'Show viewers',
                                icon: Icon(_showViewersPanel
                                    ? Icons.people_alt
                                    : Icons.people_alt_outlined),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (widget.joinToken.canPublish && _showViewersPanel)
                Positioned(
                  left: 16,
                  top: _error == null ? 126 : 202,
                  child: _LiveViewersPanel(
                    viewers: _activeViewers,
                    blockedViewers: _blockedViewers,
                    blockingViewerIds: _blockingViewerIds,
                    unblockingViewerIds: _unblockingViewerIds,
                    onBlock: _blockViewer,
                    onUnblock: _unblockViewer,
                  ),
                ),
              Positioned(
                right: 16,
                bottom: commentsBottomOffset,
                child: FloatingActionButton.small(
                  heroTag: 'comments-toggle',
                  onPressed: () =>
                      setState(() => _showCommentsPanel = !_showCommentsPanel),
                  child: Icon(_showCommentsPanel
                      ? Icons.keyboard_arrow_down
                      : Icons.chat_bubble_outline),
                ),
              ),
              if (_showCommentsPanel)
                Positioned(
                  left: 16,
                  right: widget.joinToken.canPublish ? 16 : 88,
                  bottom: commentsBottomOffset,
                  child: _LiveCommentsOverlay(
                    comments: visibleComments,
                    reactions:
                        widget.joinToken.canPublish ? _reactions : const [],
                    ownReactions:
                        widget.joinToken.canPublish ? const [] : _ownReactions,
                    expanded: true,
                  ),
                ),
              if (!widget.joinToken.canPublish)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16 + bottomInset,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_commentsOn)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: _themeAlpha(Colors.black, 0.72),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _commentController,
                                  minLines: 1,
                                  maxLines: 3,
                                  maxLength: 250,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    counterText: '',
                                    hintText: 'Comment',
                                    hintStyle: TextStyle(color: Colors.white60),
                                    border: InputBorder.none,
                                    contentPadding:
                                        EdgeInsets.symmetric(horizontal: 12),
                                  ),
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (_) => _sendComment(),
                                ),
                              ),
                              IconButton(
                                onPressed:
                                    _isSendingComment ? null : _sendComment,
                                color: Colors.white,
                                icon: const Icon(Icons.send),
                              ),
                            ],
                          ),
                        )
                      else
                        const _LiveDisabledNotice(label: 'Comments are off'),
                      if (!_reactionsOn)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child:
                              _LiveDisabledNotice(label: 'Reactions are off'),
                        ),
                    ],
                  ),
                ),
              if (!widget.joinToken.canPublish && _reactionsOn)
                Positioned(
                  right: 16,
                  bottom: 96 + bottomInset,
                  child: Column(
                    children: ['❤️', '🔥', '👏', '😂'].map((emoji) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: FloatingActionButton.small(
                          heroTag: 'reaction-$emoji',
                          onPressed: () => _sendReaction(emoji),
                          child: Text(emoji),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              if (widget.joinToken.canPublish)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _sessionEndedAfterFailure
                        ? [
                            FilledButton.tonalIcon(
                              onPressed: _isLeaving ? null : _leaveRoom,
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('Back'),
                            ),
                          ]
                        : [
                            FilledButton.tonalIcon(
                              onPressed: _isLeaving ? null : _toggleMicrophone,
                              icon: Icon(_isMicrophoneEnabled
                                  ? Icons.mic
                                  : Icons.mic_off),
                              label: Text(
                                  _isMicrophoneEnabled ? 'Mute' : 'Unmute'),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.tonalIcon(
                              onPressed: _isLeaving ? null : _toggleCamera,
                              icon: Icon(_isCameraEnabled
                                  ? Icons.videocam
                                  : Icons.videocam_off),
                              label: Text(_isCameraEnabled
                                  ? 'Camera off'
                                  : 'Camera on'),
                            ),
                          ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveViewer {
  const _LiveViewer({
    required this.userId,
    required this.identity,
    required this.username,
  });

  final String userId;
  final String identity;
  final String username;
}

class _LiveViewersPanel extends StatelessWidget {
  const _LiveViewersPanel({
    required this.viewers,
    required this.blockedViewers,
    required this.blockingViewerIds,
    required this.unblockingViewerIds,
    required this.onBlock,
    required this.onUnblock,
  });

  final List<_LiveViewer> viewers;
  final List<LiveBlockedViewer> blockedViewers;
  final Set<String> blockingViewerIds;
  final Set<String> unblockingViewerIds;
  final Future<void> Function(_LiveViewer viewer) onBlock;
  final Future<void> Function(LiveBlockedViewer viewer) onUnblock;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width - 32;

    return ConstrainedBox(
      constraints: BoxConstraints(
          maxWidth: maxWidth.clamp(260.0, 360.0).toDouble(), maxHeight: 260),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _themeAlpha(Colors.black, 0.74),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Active viewers',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                if (viewers.isEmpty)
                  const Text('No active viewers',
                      style: TextStyle(color: Colors.white70))
                else
                  ...viewers.map((viewer) {
                    final isBlocking =
                        blockingViewerIds.contains(viewer.userId);

                    return _LiveViewerRow(
                      username: viewer.username,
                      isBusy: isBlocking,
                      icon: Icons.block,
                      iconColor: Colors.red.shade200,
                      tooltip: 'Block viewer',
                      onPressed: isBlocking ? null : () => onBlock(viewer),
                    );
                  }),
                const SizedBox(height: 12),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 12),
                const Text(
                  'Blocked viewers',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                if (blockedViewers.isEmpty)
                  const Text('No blocked viewers',
                      style: TextStyle(color: Colors.white70))
                else
                  ...blockedViewers.map((viewer) {
                    final isUnblocking =
                        unblockingViewerIds.contains(viewer.userId);

                    return _LiveViewerRow(
                      username: viewer.username,
                      isBusy: isUnblocking,
                      icon: Icons.undo,
                      iconColor: Colors.green.shade200,
                      tooltip: 'Unblock viewer',
                      onPressed: isUnblocking ? null : () => onUnblock(viewer),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveViewerRow extends StatelessWidget {
  const _LiveViewerRow({
    required this.username,
    required this.isBusy,
    required this.icon,
    required this.iconColor,
    required this.tooltip,
    required this.onPressed,
  });

  final String username;
  final bool isBusy;
  final IconData icon;
  final Color iconColor;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final initial =
        username.isEmpty ? '?' : username.substring(0, 1).toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white24,
            child: Text(
              initial,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '@$username',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            onPressed: onPressed,
            color: iconColor,
            tooltip: tooltip,
            icon: isBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon),
          ),
        ],
      ),
    );
  }
}

String _formatLiveDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

  if (hours > 0) {
    return '$hours:$minutes:$seconds';
  }

  return '$minutes:$seconds';
}

String _relativeTime(DateTime dateTime) {
  final difference = DateTime.now().difference(dateTime.toLocal());

  if (difference.inMinutes < 1) {
    return 'Just now';
  }

  if (difference.inHours < 1) {
    return '${difference.inMinutes}m ago';
  }

  if (difference.inDays < 1) {
    return '${difference.inHours}h ago';
  }

  if (difference.inDays < 7) {
    return '${difference.inDays}d ago';
  }

  return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
}

class _LiveCommentsOverlay extends StatelessWidget {
  const _LiveCommentsOverlay({
    required this.comments,
    required this.reactions,
    required this.ownReactions,
    required this.expanded,
  });

  final List<LiveComment> comments;
  final List<LiveReactionCount> reactions;
  final List<String> ownReactions;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final visibleComments = expanded
        ? comments
        : comments.length > 5
            ? comments.sublist(comments.length - 5)
            : comments;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.40;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (reactions.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: reactions.map((reaction) {
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: _themeAlpha(Colors.black, expanded ? 0.42 : 0.56),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    '${reaction.emoji} ${reaction.count}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              );
            }).toList(),
          ),
        if (ownReactions.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ownReactions.map((emoji) {
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: _themeAlpha(Colors.black, expanded ? 0.42 : 0.56),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    emoji,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              );
            }).toList(),
          ),
        if ((reactions.isNotEmpty || ownReactions.isNotEmpty) &&
            visibleComments.isNotEmpty)
          const SizedBox(height: 8),
        if (visibleComments.isEmpty)
          const Text(
            'No comments yet',
            style: TextStyle(color: Colors.white70),
          )
        else
          ...visibleComments.map((comment) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _themeAlpha(Colors.black, expanded ? 0.42 : 0.56),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  child: RichText(
                    maxLines: expanded ? 4 : 2,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: const TextStyle(color: Colors.white),
                      children: [
                        TextSpan(
                          text: '@${comment.authorUsername ?? 'viewer'}  ',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        TextSpan(text: comment.body),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );

    if (!expanded) {
      return IgnorePointer(child: content);
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _themeAlpha(Colors.black, 0.72),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            reverse: true,
            child: content,
          ),
        ),
      ),
    );
  }
}

class _LiveDisabledNotice extends StatelessWidget {
  const _LiveDisabledNotice({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _themeAlpha(Colors.black, 0.64),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    required this.session,
    required this.onOpenNotification,
    required this.onUnreadCountChanged,
    super.key,
  });

  final AuthSession session;
  final Future<void> Function(AppNotification notification) onOpenNotification;
  final ValueChanged<int> onUnreadCountChanged;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _notificationsApi = NotificationsApi(apiBaseUrl: AppConfig.apiBaseUrl);
  late Future<List<AppNotification>> _notificationsFuture;
  bool _isMarkingAll = false;

  @override
  void initState() {
    super.initState();
    _notificationsFuture = _notificationsApi.list(widget.session);
  }

  Future<void> _refresh() async {
    final future = _notificationsApi.list(widget.session);
    setState(() => _notificationsFuture = future);
    final notifications = await future;
    widget.onUnreadCountChanged(
      notifications.where((notification) => notification.isUnread).length,
    );
  }

  Future<void> _markAllRead() async {
    if (_isMarkingAll) {
      return;
    }

    setState(() => _isMarkingAll = true);

    try {
      await _notificationsApi.markAllRead(widget.session);
      await _refresh();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _isMarkingAll = false);
      }
    }
  }

  Future<void> _openNotification(AppNotification notification) async {
    try {
      if (notification.isUnread) {
        await _notificationsApi.markRead(
          session: widget.session,
          id: notification.id,
        );
        await _refresh();
      }
      await widget.onOpenNotification(notification);
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error.toString())));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _isMarkingAll ? null : _markAllRead,
            icon: _isMarkingAll
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.done_all),
            tooltip: 'Mark all read',
          ),
        ],
      ),
      body: FutureBuilder<List<AppNotification>>(
        future: _notificationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _InlineState(
              icon: Icons.notifications_off_outlined,
              title: 'Unable to load notifications',
              subtitle: snapshot.error.toString(),
              actionLabel: 'Retry',
              onAction: _refresh,
            );
          }

          final notifications = snapshot.data ?? const [];
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              widget.onUnreadCountChanged(
                notifications
                    .where((notification) => notification.isUnread)
                    .length,
              );
            }
          });

          if (notifications.isEmpty) {
            return const _InlineState(
              icon: Icons.notifications_none_outlined,
              title: 'No notifications yet',
              subtitle: 'Follows, comments, and live alerts will appear here.',
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _NotificationTile(
                  notification: notification,
                  onTap: () => _openNotification(notification),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemCount: notifications.length,
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      tileColor: notification.isUnread
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(_notificationIcon(notification.type)),
          if (notification.isUnread)
            Positioned(
              right: -2,
              top: -2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox.square(dimension: 8),
              ),
            ),
        ],
      ),
      title: Text(
        notification.title,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
          '${notification.body}\n${_relativeTime(notification.createdAt)}'),
      isThreeLine: true,
      trailing: notification.isUnread
          ? const Icon(Icons.mark_email_unread_outlined)
          : const Icon(Icons.mark_email_read_outlined),
    );
  }

  IconData _notificationIcon(String type) {
    return switch (type) {
      'FOLLOW' => Icons.person_add_alt_1_outlined,
      'COMMENT' => Icons.mode_comment_outlined,
      'LIVE_STARTED' => Icons.sensors,
      'LIKE' => Icons.favorite_border,
      _ => Icons.notifications_outlined,
    };
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    required this.session,
    required this.logout,
    required this.updateSession,
    required this.themePreference,
    required this.onThemePreferenceChanged,
    super.key,
  });

  final AuthSession session;
  final VoidCallback logout;
  final Future<void> Function(AuthSession session) updateSession;
  final AppThemePreference themePreference;
  final ValueChanged<AppThemePreference> onThemePreferenceChanged;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _authApi = AuthApi(apiBaseUrl: AppConfig.apiBaseUrl);
  final _userApi = UserApi(apiBaseUrl: AppConfig.apiBaseUrl);
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _avatarUrlController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  late Future<_CreatorAccessState> _creatorStateFuture;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _isChangingPassword = false;
  bool _isCurrentPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isSubscribing = false;
  bool _isSubscriptionSyncing = false;
  bool _revenueCatConfigured = false;
  String? _selectedPlanId;

  @override
  void initState() {
    super.initState();
    _fillProfileFields();
    _creatorStateFuture = _loadCreatorState();
  }

  @override
  void didUpdateWidget(ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.session.user.id != widget.session.user.id ||
        oldWidget.session.user.displayName != widget.session.user.displayName) {
      _fillProfileFields();
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _avatarUrlController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  void _fillProfileFields() {
    _displayNameController.text = widget.session.user.displayName;
    _bioController.text = widget.session.user.bio ?? '';
    _avatarUrlController.text = widget.session.user.avatarUrl ?? '';
  }

  Future<_CreatorAccessState> _loadCreatorState() async {
    final results = await Future.wait<dynamic>([
      _userApi.subscriptionPlans(),
      _userApi.activeSubscription(widget.session),
    ]);

    final plans = results[0] as List<SubscriptionPlan>;
    final subscription = results[1] as UserSubscription?;

    return _CreatorAccessState(
      plans: plans,
      subscription: subscription,
    );
  }

  void _refreshCreatorState() {
    _creatorStateFuture = _loadCreatorState();
    setState(() {});
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    try {
      final user = await _userApi.updateProfile(
        session: widget.session,
        displayName: _displayNameController.text.trim(),
        bio: _bioController.text.trim(),
        avatarUrl: _avatarUrlController.text.trim(),
      );
      await widget.updateSession(widget.session.copyWith(user: user));
      _showMessage('Profile updated');
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteProfile() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete profile?'),
          content: const Text('Your account and profile data will be removed.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _isDeleting = true);

    try {
      await _userApi.deleteProfile(widget.session);
      widget.logout();
    } catch (error) {
      _showMessage(error.toString());
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Log out?'),
          content:
              const Text('You will need to log in again to use your account.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      widget.logout();
    }
  }

  Future<void> _changePassword() async {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;

    if (currentPassword.length < 8 || newPassword.length < 8) {
      _showMessage('Passwords must be at least 8 characters.');
      return;
    }

    setState(() => _isChangingPassword = true);

    try {
      final message = await _authApi.changePassword(
        session: widget.session,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _showMessage(message);
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isChangingPassword = false);
      }
    }
  }

  Future<void> _subscribeToCreatorPlan(_CreatorAccessState state) async {
    final planId =
        _selectedPlanId ?? (state.plans.isEmpty ? null : state.plans.first.id);

    if (planId == null) {
      _showMessage('No subscription plan is available right now');
      return;
    }

    setState(() => _isSubscribing = true);

    try {
      final plan = state.selectedPlan(planId);

      if (plan == null) {
        _showMessage('Select a subscription plan first');
        return;
      }

      await _purchaseRevenueCatPlan(plan);
      final user = await _userApi.getProfile(widget.session);
      await widget.updateSession(widget.session.copyWith(user: user));
      _showMessage('Purchase completed. Creator access will sync shortly.');
      _refreshCreatorState();
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSubscribing = false);
      }
    }
  }

  Future<void> _purchaseRevenueCatPlan(SubscriptionPlan plan) async {
    final config = await _ensureRevenueCatConfigured();

    final packageId = plan.revenueCatPackageId;

    if (packageId == null || packageId.isEmpty) {
      throw const ApiException(
          'RevenueCat package is not configured for this plan');
    }

    final offerings = await Purchases.getOfferings();
    final offeringId = plan.revenueCatOfferingId?.isNotEmpty == true
        ? plan.revenueCatOfferingId!
        : config.defaultOfferingId;
    final offering = offeringId.isNotEmpty
        ? offerings.getOffering(offeringId)
        : offerings.current;
    final package = offering?.getPackage(packageId);

    if (package == null) {
      throw const ApiException('RevenueCat package was not found');
    }

    await Purchases.purchase(PurchaseParams.package(package));
  }

  Future<RevenueCatConfig> _ensureRevenueCatConfigured() async {
    final config = await _userApi.revenueCatConfig(widget.session);
    final apiKey = Platform.isIOS ? config.iosApiKey : config.androidApiKey;

    if (apiKey.isEmpty) {
      throw const ApiException(
          'RevenueCat is not configured for this platform');
    }

    if (!_revenueCatConfigured) {
      final purchasesConfig = PurchasesConfiguration(apiKey)
        ..appUserID = widget.session.user.id;
      await Purchases.configure(purchasesConfig);
      _revenueCatConfigured = true;
    }

    return config;
  }

  Future<void> _refreshProfileAndSubscription(String message) async {
    final user = await _userApi.getProfile(widget.session);
    await widget.updateSession(widget.session.copyWith(user: user));
    _showMessage(message);
    _refreshCreatorState();
  }

  Future<void> _syncRevenueCatSubscription() async {
    if (_isSubscriptionSyncing) {
      return;
    }

    setState(() => _isSubscriptionSyncing = true);

    try {
      await _ensureRevenueCatConfigured();
      await Purchases.syncPurchases();
      await _refreshProfileAndSubscription(
          'Subscription sync requested. Status will update after RevenueCat webhook processing.');
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSubscriptionSyncing = false);
      }
    }
  }

  Future<void> _restoreRevenueCatPurchases() async {
    if (_isSubscriptionSyncing) {
      return;
    }

    setState(() => _isSubscriptionSyncing = true);

    try {
      await _ensureRevenueCatConfigured();
      await Purchases.restorePurchases();
      await _refreshProfileAndSubscription(
          'Purchases restored. Creator access will update after RevenueCat webhook processing.');
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSubscriptionSyncing = false);
      }
    }
  }

  void _showStoreCancellationInfo() {
    _showMessage(
        'Cancel or manage billing from your App Store or Google Play subscription settings. The app will update after RevenueCat sends the webhook.');
  }

  void _openCreatorDashboard() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreatorDashboardPage(
          session: widget.session,
          feedApi: FeedApi(apiBaseUrl: AppConfig.apiBaseUrl),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.session.user;
    final initial =
        (user.displayName.isNotEmpty ? user.displayName : user.username)
            .characters
            .first
            .toUpperCase();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _PageIntro(
            title: user.displayName,
            subtitle: '@${user.username} • ${user.role}',
            icon: Icons.person_outline,
            trailing: CircleAvatar(
              radius: 24,
              backgroundImage:
                  user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                      ? NetworkImage(user.avatarUrl!)
                      : null,
              child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                  ? Text(initial)
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          _SurfacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SectionTitle(
                  title: 'Appearance',
                  subtitle: 'Choose a theme or follow your phone setting.',
                ),
                const SizedBox(height: 12),
                SegmentedButton<AppThemePreference>(
                  segments: AppThemePreference.values
                      .map(
                        (preference) => ButtonSegment(
                          value: preference,
                          label: Text(preference.label),
                          icon: Icon(preference.icon),
                        ),
                      )
                      .toList(),
                  selected: {widget.themePreference},
                  onSelectionChanged: (selection) =>
                      widget.onThemePreferenceChanged(selection.first),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SurfacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SectionTitle(
                  title: 'Profile',
                  subtitle: 'Keep your public creator identity up to date.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: 'Display name',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bioController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _avatarUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Avatar URL',
                    prefixIcon: Icon(Icons.image_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _saveProfile,
                  icon: _isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Save profile'),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                const _SectionTitle(
                  title: 'Change password',
                  subtitle: 'Use your current password to set a new one.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _currentPasswordController,
                  obscureText: !_isCurrentPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Current password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() =>
                          _isCurrentPasswordVisible =
                              !_isCurrentPasswordVisible),
                      icon: Icon(_isCurrentPasswordVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _newPasswordController,
                  obscureText: !_isNewPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'New password',
                    prefixIcon: const Icon(Icons.lock_reset_outlined),
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                          () => _isNewPasswordVisible = !_isNewPasswordVisible),
                      icon: Icon(_isNewPasswordVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isChangingPassword ? null : _changePassword,
                  icon: _isChangingPassword
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_reset_outlined),
                  label: Text(_isChangingPassword
                      ? 'Updating password'
                      : 'Change password'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          if (user.role == 'USER')
            _CreatorAccessPanel(
              future: _creatorStateFuture,
              selectedPlanId: _selectedPlanId,
              isSubscribing: _isSubscribing,
              isSyncing: _isSubscriptionSyncing,
              onPlanChanged: (value) => setState(() => _selectedPlanId = value),
              onRefresh: _refreshCreatorState,
              onSubscribe: _subscribeToCreatorPlan,
              onRestorePurchases: _restoreRevenueCatPurchases,
              onSyncSubscription: _syncRevenueCatSubscription,
            ),
          if (user.role != 'USER')
            _CreatorSubscriptionPanel(
              future: _creatorStateFuture,
              onRefresh: _refreshCreatorState,
              isSyncing: _isSubscriptionSyncing,
              onManageSubscription: _showStoreCancellationInfo,
              onRestorePurchases: _restoreRevenueCatPurchases,
              onSyncSubscription: _syncRevenueCatSubscription,
            ),
          if (user.role != 'USER') ...[
            OutlinedButton.icon(
              onPressed: _openCreatorDashboard,
              icon: const Icon(Icons.dashboard_outlined),
              label: const Text('My videos and reels'),
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isDeleting ? null : _deleteProfile,
            icon: _isDeleting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
            label: const Text('Delete my profile'),
          ),
        ],
      ),
    );
  }
}

class _CreatorAccessPanel extends StatelessWidget {
  const _CreatorAccessPanel({
    required this.future,
    required this.selectedPlanId,
    required this.isSubscribing,
    required this.isSyncing,
    required this.onPlanChanged,
    required this.onRefresh,
    required this.onSubscribe,
    required this.onRestorePurchases,
    required this.onSyncSubscription,
  });

  final Future<_CreatorAccessState> future;
  final String? selectedPlanId;
  final bool isSubscribing;
  final bool isSyncing;
  final ValueChanged<String?> onPlanChanged;
  final VoidCallback onRefresh;
  final Future<void> Function(_CreatorAccessState state) onSubscribe;
  final VoidCallback onRestorePurchases;
  final VoidCallback onSyncSubscription;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_CreatorAccessState>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Could not load creator access details.'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
              const SizedBox(height: 20),
            ],
          );
        }

        final state = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Become a creator',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: selectedPlanId ??
                  (state.plans.isEmpty ? null : state.plans.first.id),
              items: state.plans.map((plan) {
                return DropdownMenuItem(
                  value: plan.id,
                  child: Text('${plan.name} - ${plan.priceLabel}'),
                );
              }).toList(),
              onChanged: onPlanChanged,
              decoration: const InputDecoration(
                labelText: 'Subscription plan',
                prefixIcon: Icon(Icons.credit_card),
              ),
            ),
            if (state.selectedPlan(selectedPlanId) != null) ...[
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.workspace_premium_outlined),
                title: Text(state.selectedPlan(selectedPlanId)!.name),
                subtitle: Text(
                    _formatPlanDetails(state.selectedPlan(selectedPlanId)!)),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isSubscribing ? null : () => onSubscribe(state),
              icon: isSubscribing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_outlined),
              label: const Text('Subscribe and become creator'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: isSyncing ? null : onRestorePurchases,
                  icon: const Icon(Icons.restore_outlined),
                  label: const Text('Restore purchases'),
                ),
                OutlinedButton.icon(
                  onPressed: isSyncing ? null : onSyncSubscription,
                  icon: isSyncing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: const Text('Sync subscription'),
                ),
              ],
            ),
            const SizedBox(height: 28),
          ],
        );
      },
    );
  }

  String _formatPlanDetails(SubscriptionPlan plan) {
    final description = plan.description == null || plan.description!.isEmpty
        ? 'Creator access'
        : plan.description!;
    return '$description • ${plan.priceLabel} • ${plan.durationDays} days';
  }
}

class _CreatorSubscriptionPanel extends StatelessWidget {
  const _CreatorSubscriptionPanel({
    required this.future,
    required this.onRefresh,
    required this.isSyncing,
    required this.onManageSubscription,
    required this.onRestorePurchases,
    required this.onSyncSubscription,
  });

  final Future<_CreatorAccessState> future;
  final VoidCallback onRefresh;
  final bool isSyncing;
  final VoidCallback onManageSubscription;
  final VoidCallback onRestorePurchases;
  final VoidCallback onSyncSubscription;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_CreatorAccessState>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Could not load subscription details.'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
              const SizedBox(height: 12),
            ],
          );
        }

        final state = snapshot.data!;
        final subscription = state.subscription;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.verified_outlined),
              title: Text('Creator access enabled'),
              subtitle: Text(
                  'RevenueCat is the source of truth for billing and renewal status.'),
            ),
            if (subscription != null) ...[
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.workspace_premium_outlined),
                title: Text(subscription.plan.name),
                subtitle: Text(_formatPrice(subscription.plan)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: Text('Expires: ${_formatDate(subscription.expiresAt)}'),
                subtitle: Text(_subscriptionStatusLine(subscription)),
              ),
              if (subscription.externalProductId != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.confirmation_number_outlined),
                  title: Text(subscription.externalProductId!),
                  subtitle: Text(subscription.externalSubscriptionId == null
                      ? 'RevenueCat product'
                      : 'Transaction: ${subscription.externalSubscriptionId}'),
                ),
              OutlinedButton.icon(
                onPressed: onManageSubscription,
                icon: const Icon(Icons.manage_accounts_outlined),
                label: const Text('Manage in store'),
              ),
            ] else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No active subscription.'),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: isSyncing ? null : onRestorePurchases,
                  icon: const Icon(Icons.restore_outlined),
                  label: const Text('Restore purchases'),
                ),
                OutlinedButton.icon(
                  onPressed: isSyncing ? null : onSyncSubscription,
                  icon: isSyncing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: const Text('Sync subscription'),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatPrice(SubscriptionPlan plan) {
    return '${plan.priceLabel} • ${plan.durationDays} days';
  }

  String _subscriptionStatusLine(UserSubscription subscription) {
    final latestEvent = subscription.latestEventAt == null
        ? null
        : ' • Synced ${_formatDate(subscription.latestEventAt!)}';
    return 'Status: ${subscription.status}${latestEvent ?? ''}';
  }
}

class _CreatorAccessState {
  const _CreatorAccessState({
    required this.plans,
    required this.subscription,
  });

  final List<SubscriptionPlan> plans;
  final UserSubscription? subscription;

  SubscriptionPlan? selectedPlan(String? planId) {
    if (plans.isEmpty) {
      return null;
    }

    return plans.firstWhere(
      (plan) => plan.id == planId,
      orElse: () => plans.first,
    );
  }
}

class FeaturePage extends StatelessWidget {
  const FeaturePage({
    required this.title,
    required this.subtitle,
    required this.icon,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
