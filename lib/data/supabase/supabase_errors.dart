import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories.dart';

const _networkMessage = 'Network error. Check your connection and try again.';
const _genericMessage = 'Something went wrong. Please try again.';

/// Messages raised by the SQL functions (`raise exception '…'`) that are
/// written for the user and may be shown as they are.
const _serverMessages = {
  'Sign in required',
  'Design unavailable',
  'Invalid task',
  'Enter number of coins',
  'Recipient not found',
  'Not enough coins',
  'Payments are not enabled',
  'Invalid pack',
};

bool _looksLikeNetwork(Object e) {
  if (e is TimeoutException) return true;
  final text = e.toString();
  return text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('Failed host lookup') ||
      text.contains('Connection refused') ||
      text.contains('Connection closed') ||
      text.contains('HandshakeException');
}

/// Prints the raw backend failure (type, message, code, details) so problems
/// can be diagnosed from the debug console.
void logBackendError(String action, Object e) {
  final extra = e is PostgrestException
      ? ' [code=${e.code} details=${e.details} hint=${e.hint}]'
      : '';
  debugPrint('[supabase] $action failed: ${e.runtimeType}: $e$extra');
}

/// Turns any failure from Supabase into an [AppException] with a message that
/// can be shown in a toast. The original error is logged by the callers.
AppException friendlyError(Object e) {
  if (e is AppException) return e;

  if (e is AuthException) {
    final code = e.code ?? '';
    final msg = e.message.toLowerCase();
    if (e is AuthRetryableFetchException || _looksLikeNetwork(e)) {
      return const AppException(_networkMessage);
    }
    if (code == 'user_already_exists' ||
        code == 'email_exists' ||
        msg.contains('already registered') ||
        msg.contains('already been registered')) {
      return const AppException(
          'An account with this email already exists. Please log in.');
    }
    if (code == 'invalid_credentials' ||
        msg.contains('invalid login credentials')) {
      return const AppException('Incorrect email or password.');
    }
    if (code == 'weak_password' || msg.contains('password should be')) {
      return const AppException('Password must be at least 8 characters.');
    }
    if (code == 'email_address_invalid' || msg.contains('email address') && msg.contains('invalid')) {
      return const AppException('Enter a valid email address.');
    }
    if (code == 'email_not_confirmed' || msg.contains('not confirmed')) {
      return const AppException(
          'Please confirm your email first, then log in.');
    }
    if (code == 'over_request_rate_limit' ||
        code == 'over_email_send_rate_limit' ||
        e.statusCode == '429') {
      return const AppException('Too many attempts. Please wait a moment and try again.');
    }
    if (code == 'signup_disabled') {
      return const AppException('Sign-ups are currently disabled.');
    }
    return AppException(e.message.isEmpty ? _genericMessage : e.message);
  }

  if (e is PostgrestException) {
    if (_serverMessages.contains(e.message)) return AppException(e.message);
    final code = e.code ?? '';
    if (code == 'PGRST205' || code == '42P01' || code == 'PGRST202') {
      return const AppException(
          'The backend is not set up yet (missing tables or functions).');
    }
    if (code == '42501' || code == 'PGRST301') {
      return const AppException('You do not have permission to do that.');
    }
    if (_looksLikeNetwork(e)) return const AppException(_networkMessage);
    return const AppException(_genericMessage);
  }

  if (e is StorageException) {
    return _looksLikeNetwork(e)
        ? const AppException(_networkMessage)
        : const AppException(_genericMessage);
  }

  if (_looksLikeNetwork(e)) return const AppException(_networkMessage);
  return const AppException(_genericMessage);
}
