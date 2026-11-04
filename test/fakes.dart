import 'dart:typed_data';
import 'package:flutter/painting.dart';
import 'package:mideas_touch/data/repositories.dart';
import 'package:mideas_touch/models/account.dart';
import 'package:mideas_touch/models/catalog_models.dart';
import 'package:mideas_touch/models/design_model.dart';

/// 1x1 white PNG, a stand-in for a template picture.
final Uint8List kTinyPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xFF, 0xFF, 0x3F,
  0x00, 0x05, 0xFE, 0x02, 0xFE, 0xA7, 0x35, 0x81, 0x84, 0x00, 0x00, 0x00,
  0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

DesignModel sampleTemplate(int id, String name,
        {String cat = 'Festivals', String? path}) =>
    DesignModel(
      id: id,
      name: name,
      cat: cat,
      desc: 'Warm Diwali wishes greeting.',
      bg: const [Color(0xFF8A6A00), Color(0xFFEFBF05)],
      biPath: path,
      els: const [],
    );

CatalogData sampleCatalog() => CatalogData(
      categories: const ['Festivals', 'Offers', 'Greetings'],
      fonts: const ['Poppins', 'Pacifico'],
      assets: const [
        StockAsset('🪔', 'diya diwali lamp'),
        StockAsset('🎂', 'cake birthday'),
      ],
      backgrounds: const [
        [Color(0xFF8A6A00), Color(0xFFEFBF05)],
        [Color(0xFF7C2D12), Color(0xFFF59E0B)],
      ],
      coinPacks: const [
        CoinPack('Basic', 10, 1, 0, id: 1),
        CoinPack('Advance', 50, 5, 2, id: 2, popular: true),
      ],
      earnTasks: const [
        EarnTask(
            key: 'follow',
            icon: '📣',
            title: 'Follow us',
            description: 'On our social media pages',
            buttonLabel: '+1 🪙',
            historyLabel: 'Followed us'),
        EarnTask(
            key: 'refer',
            icon: '🤝',
            title: 'Refer a friend',
            description: '1 coin when your friend accepts',
            buttonLabel: 'Invite',
            historyLabel: 'Friend accepted your invite'),
      ],
      banners: const [
        HomeBanner(
            tag: 'Create. Customize. Share.',
            title: 'Create beautiful promotional images in minutes',
            body: 'Pick a design, customize it, and share your design.',
            button: 'Start Creating',
            action: 'startCreating',
            colors: [Color(0xFFEFBF05), Color(0xFFF6DA6F)]),
      ],
      templates: [
        sampleTemplate(11, 'Diwali Greeting 01', path: 'templates/a.jpg'),
        sampleTemplate(12, 'Diwali Greeting 02', path: 'templates/b.jpg'),
        sampleTemplate(13, 'Diwali Greeting 03'),
        sampleTemplate(14, 'Diwali Greeting 04'),
        sampleTemplate(15, 'Diwali Greeting 05'),
      ],
    );

class FakeAccount {
  FakeAccount(this.id, this.email, this.password, this.name);
  final String id;
  final String email;
  final String password;
  final String name;
  int coins = 0;
  final unlocked = <int>[];
  final history = <CoinTx>[];
  final tasks = <String>{};
  final designs = <int, DesignModel>{};
}

/// An in-memory stand-in for Supabase that follows the same rules as the SQL
/// in supabase/backend/01_schema.sql.
class FakeBackend {
  FakeBackend({CatalogData? catalog}) : data = catalog ?? sampleCatalog();

  CatalogData data;
  final accounts = <String, FakeAccount>{};
  FakeAccount? current;

  /// Make the next catalogue load fail with this message.
  String? failCatalog;

  /// Make every user call fail with this message.
  String? failUser;

  /// Pictures served for [CatalogRepository.image] (path -> bytes).
  final pictures = <String, Uint8List>{};

  int signUps = 0;
  int signIns = 0;

  late final CatalogRepository catalogRepo = _FakeCatalogRepo(this);
  late final AuthRepository authRepo = _FakeAuthRepo(this);
  late final UserRepository userRepo = _FakeUserRepo(this);

  FakeAccount get me {
    if (failUser != null) throw AppException(failUser!);
    final a = current;
    if (a == null) throw const AppException('Sign in required');
    return a;
  }

  /// Registers an account without signing in (for login tests).
  void seedAccount(String email, String password, {String name = 'Aarav', int coins = 0}) {
    accounts[email.toLowerCase()] =
        FakeAccount('id-${accounts.length}', email, password, name)..coins = coins;
  }
}

class _FakeCatalogRepo implements CatalogRepository {
  _FakeCatalogRepo(this.b);
  final FakeBackend b;

  @override
  Future<CatalogData> load() async {
    if (b.failCatalog != null) throw AppException(b.failCatalog!);
    return b.data;
  }

  @override
  Future<Uint8List?> image(String path) async => b.pictures[path];
}

class _FakeAuthRepo implements AuthRepository {
  _FakeAuthRepo(this.b);
  final FakeBackend b;

  @override
  bool get hasSession => b.current != null;

  @override
  Future<void> signUp(
      {required String name,
      required String email,
      required String password}) async {
    b.signUps++;
    if (b.accounts.containsKey(email.toLowerCase())) {
      throw const AppException(
          'An account with this email already exists. Please log in.');
    }
    if (password.length < 8) {
      throw const AppException('Password must be at least 8 characters.');
    }
    b.seedAccount(email, password, name: name);
    b.current = b.accounts[email.toLowerCase()];
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    b.signIns++;
    final a = b.accounts[email.toLowerCase()];
    if (a == null || a.password != password) {
      throw const AppException('Incorrect email or password.');
    }
    b.current = a;
  }

  @override
  Future<void> signOut() async => b.current = null;
}

class _FakeUserRepo implements UserRepository {
  _FakeUserRepo(this.b);
  final FakeBackend b;

  @override
  Future<UserSnapshot> load() async {
    final a = b.me;
    return UserSnapshot(
      name: a.name,
      email: a.email,
      coins: a.coins,
      unlocked: [...a.unlocked],
      history: [...a.history],
      doneTasks: {...a.tasks},
      designs: a.designs.values.toList().reversed.toList(),
    );
  }

  @override
  Future<bool> unlockTemplate(int templateId) async {
    final a = b.me;
    if (a.unlocked.contains(templateId)) return true;
    if (a.coins < 1) return false;
    a.coins--;
    a.unlocked.add(templateId);
    a.history.insert(0, CoinTx('Unlocked template $templateId', -1));
    return true;
  }

  @override
  Future<bool> claimTask(String key) async {
    final a = b.me;
    if (!a.tasks.add(key)) return false;
    a.coins++;
    a.history.insert(0, CoinTx('Task $key', 1));
    return true;
  }

  @override
  Future<void> sendCoins(String recipientEmail, int amount) async {
    final a = b.me;
    final r = b.accounts[recipientEmail.toLowerCase()];
    if (r == null || r == a) throw const AppException('Recipient not found');
    if (a.coins < amount) throw const AppException('Not enough coins');
    a.coins -= amount;
    r.coins += amount;
    a.history.insert(0, CoinTx('Sent to $recipientEmail', -amount));
  }

  @override
  Future<void> buyPack(int packId) async {
    final a = b.me;
    final p = b.data.coinPacks.firstWhere((p) => p.id == packId);
    a.coins += p.total;
    a.history.insert(0, CoinTx('Bought ₹${p.price} pack', p.total));
  }

  @override
  Future<void> saveDesign(DesignModel design) async =>
      b.me.designs[design.id] = design;

  @override
  Future<void> deleteDesign(int id) async => b.me.designs.remove(id);
}
