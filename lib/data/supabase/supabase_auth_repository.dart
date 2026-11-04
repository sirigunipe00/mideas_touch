import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories.dart';
import 'supabase_errors.dart';

/// Supabase Auth (e-mail + password). The session is persisted and refreshed
/// by supabase_flutter itself.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  bool get hasSession => _client.auth.currentSession != null;

  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        // The `on_auth_user_created` trigger copies this into public.profiles.
        data: {'full_name': name},
      );
      if (res.session != null) return;
      // No session means Supabase did not sign the user in:
      if (res.user != null && (res.user!.identities?.isEmpty ?? false)) {
        // E-mail confirmation is on and the address is already registered
        // (Supabase hides that by returning a user without identities).
        throw const AppException(
            'An account with this email already exists. Please log in.');
      }
      throw const AppException(
          'Registration needs e-mail confirmation, which is still switched on '
          'in the Supabase dashboard (Authentication › Providers › Email).');
    } on AppException {
      rethrow;
    } catch (e) {
      logBackendError('sign up', e);
      throw friendlyError(e);
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } catch (e) {
      logBackendError('sign in', e);
      throw friendlyError(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      // Even if the server cannot be reached the local session is cleared.
      logBackendError('sign out', e);
    }
  }
}
