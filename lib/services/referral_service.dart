import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Captures invite deep links and keeps a pending referrer id until signup.
class ReferralService {
  ReferralService();

  static const _prefsKey = 'pending_referrer_id';
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  /// Start listening for invite links (`…/invite/{userId}`).
  Future<void> start() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) await _captureUri(initial);
    } catch (e) {
      debugPrint('[referral] initial link failed: $e');
    }
    await _sub?.cancel();
    _sub = _appLinks.uriLinkStream.listen(
      (uri) {
        unawaited(_captureUri(uri));
      },
      onError: (Object e) {
        debugPrint('[referral] link stream error: $e');
      },
    );
  }

  Future<void> _captureUri(Uri uri) async {
    final id = referrerIdFromUri(uri);
    if (id != null) await savePendingReferrerId(id);
  }

  /// Parses `/invite/{uuid}` from https or custom-scheme links.
  static String? referrerIdFromUri(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final inviteIdx = segments.indexOf('invite');
    if (inviteIdx >= 0 && inviteIdx + 1 < segments.length) {
      final id = segments[inviteIdx + 1];
      if (_uuid.hasMatch(id)) return id.toLowerCase();
    }
    // mideastouch://invite/<uuid>
    if (uri.host == 'invite' && segments.isNotEmpty) {
      final id = segments.first;
      if (_uuid.hasMatch(id)) return id.toLowerCase();
    }
    final q = uri.queryParameters['ref'] ?? uri.queryParameters['referrer'];
    if (q != null && _uuid.hasMatch(q)) return q.toLowerCase();
    return null;
  }

  Future<void> savePendingReferrerId(String id) async {
    if (!_uuid.hasMatch(id)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, id.toLowerCase());
    debugPrint('[referral] pending referrer saved');
  }

  Future<String?> peekPendingReferrerId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_prefsKey);
    if (id == null || !_uuid.hasMatch(id)) return null;
    return id.toLowerCase();
  }

  Future<String?> takePendingReferrerId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_prefsKey);
    if (id == null || !_uuid.hasMatch(id)) return null;
    await prefs.remove(_prefsKey);
    return id.toLowerCase();
  }

  Future<void> clearPendingReferrerId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  void dispose() {
    unawaited(_sub?.cancel());
    _sub = null;
  }

  /// Public invite URL embedded in share messages.
  static String inviteUrlFor(String userId) =>
      'https://mideas-touch.app/invite/$userId';

  /// Custom scheme useful for local / adb testing.
  static String customInviteUrlFor(String userId) =>
      'mideastouch://invite/$userId';

  /// Whether this platform supports opening https app links here.
  static bool get supportsHttpsAppLinks =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);
}
