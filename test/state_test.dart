import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mideas_touch/data/catalog.dart';
import 'package:mideas_touch/models/design_element.dart';
import 'package:mideas_touch/state/catalog_cubit.dart';
import 'package:mideas_touch/state/editor_cubit.dart';
import 'package:mideas_touch/state/nav_cubit.dart';
import 'package:mideas_touch/state/session_cubit.dart';

void main() {
  group('Catalog', () {
    test('ships the artifact sample data', () {
      final templates = Catalog.templates();
      expect(templates, hasLength(8));
      expect(Catalog.fonts, hasLength(7));
      expect(Catalog.assets, hasLength(12));
      expect(Catalog.backgrounds, hasLength(6));
      expect(Catalog.coinPacks.map((p) => p.price), [10, 50, 100]);
      expect(Catalog.savedDesigns(templates), hasLength(3));
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

  group('SessionCubit', () {
    test('signing in seeds designs once; coins and unlocking work', () {
      final templates = Catalog.templates();
      final s = SessionCubit(seedDesigns: Catalog.savedDesigns(templates));
      expect(s.state.signedIn, isFalse);
      s.signIn();
      expect(s.state.user?.name, 'Aarav');
      expect(s.state.designs, hasLength(3));
      expect(s.earn('f', 'Followed us'), isTrue);
      expect(s.earn('f', 'Followed us'), isFalse);
      expect(s.state.coins, 1);
      expect(s.state.isLocked(templates[0]), isTrue);
      s.unlock(templates[0]);
      expect(s.state.coins, 0);
      expect(s.state.isLocked(templates[0]), isFalse);
      expect(s.sendCoins('', '1'), isNotNull);
      s.close();
    });
  });

  group('EditorCubit', () {
    test('adds elements with undo / redo and burst-debounced sliders', () async {
      final catalog = CatalogCubit();
      final editor = EditorCubit();
      editor.open(catalog.state.templates.first);
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
      await catalog.close();
    });
  });
}
