import 'package:supabase_flutter/supabase_flutter.dart';

/// Backend connection settings, injected at build time:
///
///     flutter run --dart-define-from-file=config/supabase.json
///
/// `config/supabase.json` is git-ignored. Only the *publishable* (anon) key
/// belongs here; every table is protected by Row Level Security.
class SupabaseConfig {
  const SupabaseConfig._();

  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  /// Storage bucket that holds template pictures.
  static const assetsBucket = 'app-assets';

  /// Call once before `runApp`.
  static Future<void> initialize() => Supabase.initialize(
        url: url,
        publishableKey: publishableKey,
        authOptions: const FlutterAuthClientOptions(autoRefreshToken: true),
      );
}
