import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mideas_touch/app/app_controller.dart';
import 'package:mideas_touch/data/mappers.dart';
import 'package:mideas_touch/data/supabase/supabase_errors.dart';
import 'package:mideas_touch/models/design_element.dart';
import 'package:mideas_touch/models/design_model.dart';
import 'package:mideas_touch/state/catalog_cubit.dart';
import 'package:mideas_touch/state/editor_cubit.dart';
import 'package:mideas_touch/state/nav_cubit.dart';
import 'package:mideas_touch/state/session_cubit.dart';
import 'package:mideas_touch/state/settings_cubit.dart';
import 'package:mideas_touch/state/studio_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fakes.dart';

/// All cubits + the controller wired to the in-memory backend.
class Harness {
  Harness({FakeBackend? backend}) : backend = backend ?? FakeBackend() {
    nav = NavCubit();
    session = SessionCubit();
    catalog = CatalogCubit(this.backend.catalogRepo);
    editor = EditorCubit();
    studio = StudioCubit();
    app = AppController(
      nav: nav,
      session: session,
      catalog: catalog,
      editor: editor,
      studio: studio,
      settings: SettingsCubit(),
      auth: this.backend.authRepo,
      users: this.backend.userRepo,
    );
  }

  final FakeBackend backend;
  late final NavCubit nav;
  late final SessionCubit session;
  late final CatalogCubit catalog;
  late final EditorCubit editor;
  late final StudioCubit studio;
  late final AppController app;

  String? get toast => app.toasts.value?.message;

  Future<void> register({String email = 'me@example.com', String name = 'Tayyab'}) async {
    session.setRegistering(true);
    session.setFullName(name);
    await app.submitAuth(email: email, password: 'password1');
    await pumpEventQueue(); // the action that needed login runs async
  }

  Future<void> dispose() async {
    app.dispose();
    await nav.close();
    await session.close();
    await catalog.close();
    await editor.close();
    await studio.close();
  }
}

void main() {
  group('row mappers', () {
    test('a templates row becomes a design with its layers in z order', () {
      final d = templateFromRow({
        'id': 7,
        'name': 'Diwali Greeting 01',
        'description': 'Warm wishes',
        'bg_from': '#adaaa6',
        'bg_to': '#eee6d5',
        'background_image_path': 'templates/diwali-greeting-01.jpg',
        'author_name': 'Studio Team',
        'is_premium': false,
        'price_inr': 0,
        'categories': {'name': 'Festivals'},
        'template_elements': [
          {
            'z_index': 1,
            'kind': 'text',
            'x': 8,
            'y': 9.5,
            'w': 84,
            'rotation': 0,
            'text_content': 'Hello',
            'font_family': 'Pacifico',
            'font_size': 44,
            'color': '#ffffff',
            'bold': true,
            'text_align': 'left',
          },
          {
            'z_index': 0,
            'kind': 'shape',
            'x': 12,
            'y': 77,
            'w': 76,
            'h': 12,
            'rotation': 0,
            'fill': '#000000',
            'shape_style': 'pill',
          },
        ],
      });
      expect(d.id, 7);
      expect(d.cat, 'Festivals');
      expect(d.biPath, 'templates/diwali-greeting-01.jpg');
      expect(d.bi, isNull);
      expect(d.bg.first, const Color(0xFFADAAA6));
      expect(d.els.map((e) => e.kind),
          [ElementKind.shape, ElementKind.text]);
      expect(d.els[1].font, 'Pacifico');
      expect(d.els[1].align, TextAlign.left);
      expect(d.els[1].y, 9.5);
    });

    test('a design survives the trip to user_designs and back', () {
      const design = DesignModel(
        id: 1700000000123,
        name: 'My card',
        cat: 'Festivals',
        bg: [Color(0xFF111827), Color(0xFF6D28D9)],
        biPath: 'templates/diwali-greeting-02.jpg',
        sourceId: 12,
        status: 'Completed',
        els: [
          DesignElement.text(
              x: 8, y: 9, w: 84, text: 'Hi\nthere', size: 40, color: Color(0xFFFFFFFF), bold: true),
          DesignElement.shape(
              x: 1, y: 2, w: 30, h: 10, fill: Color.fromRGBO(0, 0, 0, .28), shape: ShapeStyle.pill),
          DesignElement.image(x: 29, y: 37, w: 42, emoji: '🪔', photo: true),
        ],
      );
      final row = userDesignToRow(design, 'user-1');
      expect(row['user_id'], 'user-1');
      expect(row['bg_from'], '#111827');
      expect(row['status'], 'Completed');
      final back = userDesignFromRow({
        ...row,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      expect(back.id, design.id);
      expect(back.name, 'My card');
      expect(back.biPath, design.biPath);
      expect(back.sourceId, 12);
      expect(back.status, 'Completed');
      expect(back.mod, 'Just now');
      expect(back.els, hasLength(3));
      expect(back.els[0].text, 'Hi\nthere');
      expect(back.els[0].bold, isTrue);
      expect(back.els[1].shape, ShapeStyle.pill);
      expect(back.els[1].fill.alpha, closeTo(71, 1));
      expect(back.els[2].emoji, '🪔');
      expect(back.els[2].photo, isTrue);
    });

    test('"last edited" text', () {
      final now = DateTime(2026, 11, 3, 18, 0);
      expect(formatModified(DateTime(2026, 11, 3, 17, 59, 40), now), 'Just now');
      expect(formatModified(DateTime(2026, 11, 3, 10, 42), now), 'Today, 10:42 AM');
      expect(formatModified(DateTime(2026, 11, 2, 18, 15), now), 'Yesterday, 6:15 PM');
      expect(formatModified(DateTime(2026, 10, 28, 16, 5), now), 'Oct 28, 4:05 PM');
      expect(formatModified(DateTime(2026, 11, 3, 0, 5), now), 'Today, 12:05 AM');
    });
  });

  group('backend errors are readable', () {
    test('auth errors', () {
      String msg(Object e) => friendlyError(e).message;
      expect(msg(const AuthApiException('User already registered', statusCode: '422', code: 'user_already_exists')),
          contains('already exists'));
      expect(msg(const AuthApiException('Invalid login credentials', statusCode: '400', code: 'invalid_credentials')),
          'Incorrect email or password.');
      expect(msg(const AuthApiException('Password should be at least 6 characters', code: 'weak_password')),
          'Password must be at least 8 characters.');
      expect(msg(AuthRetryableFetchException(message: 'Failed host lookup')),
          contains('Network error'));
    });

    test('database and unknown errors', () {
      String msg(Object e) => friendlyError(e).message;
      expect(msg(const PostgrestException(message: 'Not enough coins')), 'Not enough coins');
      expect(msg(const PostgrestException(message: 'relation x does not exist', code: '42P01')),
          contains('not set up'));
      expect(msg(const PostgrestException(message: 'boom', code: 'XX000')),
          'Something went wrong. Please try again.');
      expect(msg(Exception('SocketException: Failed host lookup')),
          contains('Network error'));
    });
  });

  group('NavCubit', () {
    test('keeps a history for the back button', () {
      final nav = NavCubit();
      nav.go(AppView.templateDetail, templateId: 2);
      nav.go(AppView.templateDetail, templateId: 4);
      expect(nav.state.templateId, 4);
      nav.back();
      expect(nav.state.view, AppView.templateDetail);
      nav.back();
      expect(nav.state.view, AppView.home);
      nav.close();
    });
  });

  group('CatalogCubit', () {
    test('loads the catalogue, then fills in the pictures', () async {
      final backend = FakeBackend()..pictures['templates/a.jpg'] = kTinyPng;
      final cubit = CatalogCubit(backend.catalogRepo);
      expect(cubit.state.loading, isTrue);
      await cubit.load();
      expect(cubit.state.status, CatalogStatus.ready);
      expect(cubit.state.templates, hasLength(5));
      expect(cubit.state.categories, ['Festivals', 'Offers', 'Greetings']);
      expect(cubit.state.byId(11)!.bi, same(kTinyPng));
      // picture b is missing in Storage: the card keeps its gradient
      expect(cubit.state.byId(12)!.bi, isNull);
      await cubit.close();
    });

    test('reports a failed load and recovers on retry', () async {
      final backend = FakeBackend()..failCatalog = 'Network error. Check your connection and try again.';
      final cubit = CatalogCubit(backend.catalogRepo);
      await cubit.load();
      expect(cubit.state.status, CatalogStatus.error);
      expect(cubit.state.error, contains('Network error'));
      backend.failCatalog = null;
      await cubit.load();
      expect(cubit.state.status, CatalogStatus.ready);
      await cubit.close();
    });
  });

  group('AppController + backend', () {
    late Harness h;
    setUp(() async {
      h = Harness();
      await h.app.start();
    });
    tearDown(() => h.dispose());

    test('registration is validated before anything is sent', () async {
      h.session.setRegistering(true);
      await h.app.submitAuth(email: 'not-an-email', password: 'password1');
      expect(h.toast, 'Enter a valid email address');
      await h.app.submitAuth(email: 'me@example.com', password: 'short');
      expect(h.toast, 'Password must be at least 8 characters');
      expect(h.backend.signUps, 0);
      expect(h.session.state.signedIn, isFalse);
    });

    test('registers, loads the profile, and runs the action that needed login', () async {
      h.app.use(11);
      await pumpEventQueue(); // guest: asks to register first
      expect(h.nav.state.sheet, isA<RegisterSheet>());
      await h.register();
      expect(h.session.state.signedIn, isTrue);
      expect(h.session.state.user!.name, 'Tayyab');
      expect(h.session.state.user!.email, 'me@example.com');
      expect(h.session.state.coins, 0);
      expect(h.session.state.designs, isEmpty);
      expect(h.toast, 'Registered successfully');
      expect(h.session.state.busy, isFalse);
      // …then the pending "use this design" ran: no coin -> "You need 1 coin"
      expect(h.nav.state.sheet, isA<NoCoinsSheet>());
    });

    test('the name defaults to the e-mail prefix', () async {
      await h.register(name: '', email: 'aarav.k@example.com');
      expect(h.session.state.user!.name, 'aarav.k');
    });

    test('a duplicate e-mail is reported and nothing changes', () async {
      h.backend.seedAccount('me@example.com', 'password1');
      await h.register();
      expect(h.toast, contains('already exists'));
      expect(h.session.state.signedIn, isFalse);
      expect(h.session.state.busy, isFalse);
    });

    test('login: wrong password, then the right one', () async {
      h.backend.seedAccount('me@example.com', 'password1', name: 'Aarav', coins: 3);
      h.session.setRegistering(false);
      await h.app.submitAuth(email: 'me@example.com', password: 'wrongpass');
      expect(h.toast, 'Incorrect email or password.');
      expect(h.session.state.signedIn, isFalse);
      await h.app.submitAuth(email: 'ME@example.com', password: 'password1');
      expect(h.session.state.signedIn, isTrue);
      expect(h.session.state.coins, 3);
      expect(h.toast, 'Logged in successfully');
    });

    test('a restored session loads the user at start-up', () async {
      h.backend.seedAccount('me@example.com', 'password1', coins: 2);
      h.backend.current = h.backend.accounts['me@example.com'];
      await h.app.start();
      expect(h.session.state.signedIn, isTrue);
      expect(h.session.state.coins, 2);
    });

    test('logout clears the session', () async {
      await h.register();
      await h.app.logout();
      expect(h.session.state.signedIn, isFalse);
      expect(h.backend.current, isNull);
      expect(h.nav.state.view, AppView.home);
    });

    test('earning is once per task and coins come from the server', () async {
      await h.register();
      await h.app.earn('follow');
      expect(h.session.state.coins, 1);
      expect(h.session.state.done['follow'], isTrue);
      expect(h.toast, '+1 coin earned');
      await h.app.earn('follow');
      expect(h.session.state.coins, 1);
      expect(h.session.state.history, hasLength(1));
    });

    test('unlocking spends a coin, opens the editor and remembers the design', () async {
      await h.register();
      await h.app.earn('follow');
      h.nav.closeSheet();
      h.app.use(11);
      await pumpEventQueue();
      expect(h.nav.state.sheet, isA<UnlockSheet>());
      await h.app.unlock();
      expect(h.session.state.coins, 0);
      expect(h.session.state.unlocked, [11]);
      expect(h.nav.state.view, AppView.editor);
      expect(h.editor.state.design!.sourceId, 11);
      expect(h.editor.state.design!.name, 'Diwali Greeting 01');
    });

    test('unlocking without a coin shows the "get coins" sheet', () async {
      await h.register();
      h.nav.closeSheet();
      h.app.use(11);
      await pumpEventQueue();
      expect(h.nav.state.sheet, isA<NoCoinsSheet>());
      expect(h.session.state.unlocked, isEmpty);
    });

    test('buying a pack and sending coins update the wallet', () async {
      h.backend.seedAccount('friend@example.com', 'password1');
      await h.register();
      await h.app.buy(h.catalog.state.data.coinPacks[1]);
      expect(h.session.state.coins, 7);
      expect(h.toast, 'Payment successful (demo)');

      await h.app.sendCoins('', '1');
      expect(h.toast, 'Enter who to send to');
      await h.app.sendCoins('friend@example.com', '0');
      expect(h.toast, 'Enter number of coins');
      await h.app.sendCoins('friend@example.com', '99');
      expect(h.toast, 'Not enough coins');
      await h.app.sendCoins('nobody@example.com', '1');
      expect(h.toast, 'Recipient not found');
      await h.app.sendCoins('friend@example.com', '2');
      expect(h.toast, '2 coin(s) sent');
      expect(h.session.state.coins, 5);
      expect(h.backend.accounts['friend@example.com']!.coins, 2);
    });

    test('saving and deleting designs go through the backend', () async {
      await h.register();
      final design = sampleTemplate(11, 'Diwali Greeting 01').copyWith(id: 555, status: 'Draft');
      h.editor.open(design);
      await h.app.save();
      expect(h.backend.me.designs.keys, [555]);
      expect(h.session.state.designs.single.id, 555);
      expect(h.toast, 'Design saved successfully');

      await h.app.deleteSaved(555);
      expect(h.backend.me.designs, isEmpty);
      expect(h.session.state.designs, isEmpty);
    });

    test('a failed save shows the "Save error" sheet and keeps nothing', () async {
      await h.register();
      h.editor.open(sampleTemplate(11, 'x').copyWith(id: 9));
      h.backend.failUser = 'Network error. Check your connection and try again.';
      await h.app.save();
      expect(h.nav.state.sheet, isA<ErrorSheet>());
      expect(h.session.state.designs, isEmpty);
    });

    test('"Start Creating" opens the first template', () async {
      await h.register();
      await h.app.earn('follow');
      h.nav.closeSheet();
      h.app.runBannerAction(BannerAction.startCreating);
      await pumpEventQueue();
      expect(h.nav.state.sheet, isA<UnlockSheet>());
      expect((h.nav.state.sheet as UnlockSheet).designId, 11);
    });
  });

  group('SessionCubit', () {
    test('keeps the creator-mode override when the wallet refreshes', () async {
      final h = Harness();
      await h.app.start();
      await h.register();
      h.session.toggleCreator();
      expect(h.session.state.isCreator, isTrue);
      await h.app.earn('follow');
      expect(h.session.state.isCreator, isTrue);
      await h.dispose();
    });
  });

  group('EditorCubit', () {
    test('adds elements with undo / redo and burst-debounced sliders', () async {
      final editor = EditorCubit();
      editor.open(sampleTemplate(11, 'Diwali Greeting 01'));
      final before = editor.state.design!.els.length;

      editor.addElement(const DesignElement.shape(
          x: 30, y: 30, w: 30, h: 30, fill: Color(0xFFFDE68A)));
      expect(editor.state.design!.els.length, before + 1);
      expect(editor.state.selected, before);
      expect(editor.state.canUndo, isTrue);

      editor.undo();
      expect(editor.state.design!.els.length, before);
      expect(editor.state.canRedo, isTrue);
      editor.redo();
      expect(editor.state.design!.els.length, before + 1);

      editor.select(before);

      // Several slider ticks in one burst create a single undo point.
      final undoDepth = editor.state.undoStack.length;
      editor.slide(rotation: 10);
      editor.slide(rotation: 20);
      editor.slide(rotation: 30);
      expect(editor.state.undoStack.length, undoDepth + 1);
      expect(editor.state.selectedElement!.r, 30);

      editor.deleteSelected();
      expect(editor.state.design!.els.length, before);
      await editor.close();
    });

    test('background changes undo back to the template picture', () async {
      final editor = EditorCubit();
      final template = sampleTemplate(11, 'x', path: 'templates/a.jpg')
          .copyWith(bi: kTinyPng);
      editor.open(template);
      editor.setBackground(const [Color(0xFF111827), Color(0xFF6D28D9)]);
      expect(editor.state.design!.bi, isNull);
      expect(editor.state.design!.biPath, isNull);
      editor.undo();
      expect(editor.state.design!.bi, same(kTinyPng));
      expect(editor.state.design!.biPath, 'templates/a.jpg');
      await editor.close();
    });
  });
}
