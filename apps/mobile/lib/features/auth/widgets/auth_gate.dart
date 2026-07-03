import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/models/auth_session.dart';
import '../../../core/services/location_sync_service.dart';
import '../../../core/storage/session_store.dart';
import '../services/auth_api.dart';
import 'auth_page.dart';

typedef AuthenticatedBuilder = Widget Function(
  AuthSession session,
  VoidCallback logout,
  Future<void> Function(AuthSession session) updateSession,
);

class AuthGate extends StatefulWidget {
  const AuthGate({
    required this.builder,
    super.key,
  });

  final AuthenticatedBuilder builder;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  final _sessionStore = SessionStore();
  final _authApi = AuthApi(apiBaseUrl: AppConfig.apiBaseUrl);
  final _locationSyncService =
      LocationSyncService(apiBaseUrl: AppConfig.apiBaseUrl);

  AuthSession? _session;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restoreSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final session = _session;

    if (state == AppLifecycleState.resumed && session != null) {
      _syncLocation(session);
    }
  }

  Future<void> _restoreSession() async {
    final session = await _sessionStore.read();

    if (!mounted) {
      return;
    }

    setState(() {
      _session = session;
      _isLoading = false;
    });

    if (session != null) {
      await _syncLocation(session);
    }
  }

  Future<void> _handleAuthenticated(AuthSession session) async {
    await _sessionStore.save(session);

    if (!mounted) {
      return;
    }

    setState(() => _session = session);
    await _syncLocation(session);
  }

  Future<void> _logout() async {
    await _sessionStore.clear();

    if (!mounted) {
      return;
    }

    setState(() => _session = null);
  }

  Future<void> _updateSession(AuthSession session) async {
    await _sessionStore.save(session);

    if (!mounted) {
      return;
    }

    setState(() => _session = session);
  }

  Future<void> _syncLocation(AuthSession session) async {
    try {
      await _locationSyncService.syncOnceAfterAuth(
        userId: session.user.id,
        accessToken: session.accessToken,
      );
    } catch (_) {
      // Location is useful for insights, but auth should never fail because it is unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (session == null) {
      return AuthPage(
        authApi: _authApi,
        onAuthenticated: _handleAuthenticated,
      );
    }

    return widget.builder(session, _logout, _updateSession);
  }
}
