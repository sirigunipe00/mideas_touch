import 'dart:typed_data';
import '../models/catalog_models.dart';
import '../models/design_model.dart';

/// An error whose [message] is safe to show to the user as a toast.
class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Everything the app shows that is not specific to a user: categories,
/// templates, coin packs, banners … plus the pictures in Storage.
abstract class CatalogRepository {
  /// Loads the whole catalogue. Template pictures are NOT included
  /// ([DesignModel.bi] is null); fetch them with [image].
  /// Throws [AppException].
  Future<CatalogData> load();

  /// The bytes of a picture in Storage (`app-assets`), or `null` when it
  /// cannot be fetched. Results are kept in memory for the app session only.
  Future<Uint8List?> image(String path);
}

/// Registration, login and the persisted session (Supabase Auth).
abstract class AuthRepository {
  /// A session was restored from the previous app launch.
  bool get hasSession;

  /// Registers and signs in immediately (no e-mail confirmation).
  /// Throws [AppException] with a user-readable message.
  Future<void> signUp(
      {required String name, required String email, required String password});

  /// Throws [AppException] with a user-readable message.
  Future<void> signIn({required String email, required String password});

  Future<void> signOut();
}

/// The signed-in user's profile, wallet and saved designs.
/// Every method throws [AppException] on failure.
abstract class UserRepository {
  Future<UserSnapshot> load();

  /// Spends 1 coin. `false` when the user has no coin left.
  Future<bool> unlockTemplate(int templateId);

  /// `true` when the reward was newly granted.
  Future<bool> claimTask(String key);

  Future<void> sendCoins(String recipientEmail, int amount);

  /// Demo purchase (see `buy_coin_pack` in the SQL).
  Future<void> buyPack(int packId);

  Future<void> saveDesign(DesignModel design);

  Future<void> deleteDesign(int id);
}
