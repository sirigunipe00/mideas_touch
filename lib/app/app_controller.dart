import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import '../models/account.dart';
import '../models/design_element.dart';
import '../models/design_model.dart';
import '../services/export_service.dart';
import '../state/catalog_cubit.dart';
import '../state/editor_cubit.dart';
import '../state/nav_cubit.dart';
import '../state/session_cubit.dart';
import '../state/settings_cubit.dart';
import '../state/studio_cubit.dart';

class ToastEvent {
  const ToastEvent(this.message, this.id);
  final String message;
  final int id;
}

enum BannerAction { startCreating, earnCoins, seePacks, explore }

/// Application actions that span several cubits — the counterpart of the
/// artifact's global functions (`need`, `use`, `unlock`, `save`, `earn`, …).
class AppController {
  AppController({
    required this.nav,
    required this.session,
    required this.catalog,
    required this.editor,
    required this.studio,
    required this.settings,
    ExportService? exporter,
  }) : exporter = exporter ?? ExportService();

  final NavCubit nav;
  final SessionCubit session;
  final CatalogCubit catalog;
  final EditorCubit editor;
  final StudioCubit studio;
  final SettingsCubit settings;
  final ExportService exporter;

  final ValueNotifier<ToastEvent?> toasts = ValueNotifier(null);
  int _toastId = 0;
  VoidCallback? _pending;
  int _exportToken = 0;

  static const inviteMessage = 'Hey, have send you a beautiful Creation App';

  String get inviteUrl {
    final name = (session.state.user?.name ?? 'friend')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    return 'https://mideas-touch.app/invite/$name';
  }

  String shareLinkFor(DesignModel d) =>
      'https://mideas-touch.app/s/${d.id.toRadixString(36)}';

  void toast(String message) {
    toasts.value = ToastEvent(message, ++_toastId);
  }

  // ---- navigation helpers ----------------------------------------------

  void tab(AppView view) {
    editor.deselect();
    nav.tab(view);
  }

  void openTemplate(int id) => nav.go(AppView.templateDetail, templateId: id);

  void chooseCategory(String category) {
    catalog.setQuery(category);
    tab(AppView.search);
  }

  void openWallet() => need(() => nav.go(AppView.wallet));

  void runBannerAction(BannerAction action) {
    switch (action) {
      case BannerAction.startCreating:
        use(1);
      case BannerAction.earnCoins:
      case BannerAction.seePacks:
        openWallet();
      case BannerAction.explore:
        chooseCategory('Festivals');
    }
  }

  // ---- account ---------------------------------------------------------

  /// Runs [action] now when signed in, otherwise asks the user to register
  /// first and runs it afterwards.
  void need(VoidCallback action) {
    if (session.state.signedIn) {
      action();
    } else {
      _pending = action;
      nav.openSheet(const RegisterSheet());
    }
  }

  void signIn() {
    session.signIn();
    studio.resetOnLogin();
    nav.closeSheet();
    final pending = _pending;
    _pending = null;
    toast(session.state.isCreator ? 'Welcome, creator' : 'Registered successfully');
    pending?.call();
  }

  void logout() {
    session.logout();
    studio.resetOnLogin();
    tab(AppView.home);
  }

  void toggleCreatorMode() {
    if (!session.state.signedIn) return;
    session.toggleCreator();
    toast(session.state.isCreator
        ? 'Creator mode on · Studio tab unlocked'
        : 'Creator mode off');
    if (!session.state.isCreator && nav.state.view == AppView.studio) {
      tab(AppView.home);
    }
  }

  // ---- coins -----------------------------------------------------------

  void earn(String key, String label) {
    if (session.earn(key, label)) toast('+1 coin earned');
  }

  void buy(CoinPack pack) {
    session.addCoins(pack.total, 'Bought ₹${pack.price} pack');
    toast('Payment successful (demo)');
  }

  void sendCoins(String recipient, String amount) {
    final n = (double.tryParse(amount.trim()) ?? 0).floor();
    final error = session.sendCoins(recipient, amount);
    if (error != null) {
      toast(error);
      return;
    }
    nav.closeSheet();
    toast('$n coin(s) sent');
  }

  Future<void> inviteCopy() async {
    try {
      await Clipboard.setData(ClipboardData(text: '$inviteMessage $inviteUrl'));
    } catch (_) {}
    session.markInviteSent();
    nav.closeSheet();
    toast('Invite message copied');
  }

  Future<void> inviteShare() async {
    try {
      final result = await Share.share('$inviteMessage $inviteUrl');
      if (result.status == ShareResultStatus.success) {
        session.markInviteSent();
        nav.closeSheet();
        return;
      }
    } catch (_) {}
    await inviteCopy();
  }

  // ---- designs ---------------------------------------------------------

  void use(int id) => need(() => _use2(id));

  void _use2(int id) {
    final d = catalog.state.byId(id);
    if (d == null) return;
    if (session.state.isLocked(d)) {
      if (session.state.coins < 1) {
        nav.openSheet(const NoCoinsSheet());
      } else {
        nav.openSheet(UnlockSheet(id));
      }
      return;
    }
    editor.open(
      d.copyWith(
          id: DateTime.now().millisecondsSinceEpoch,
          status: 'Draft',
          mod: 'Just now'),
      tool: EditorTool.text,
    );
    nav.go(AppView.editor);
  }

  void unlock() {
    final sheet = nav.state.sheet;
    if (sheet is! UnlockSheet) return;
    final d = catalog.state.byId(sheet.designId);
    if (d == null) return;
    session.unlock(d);
    nav.closeSheet();
    _use2(d.id);
  }

  void editSaved(int id) {
    final d = session.state.designs.where((x) => x.id == id).firstOrNull;
    if (d == null) return;
    editor.open(d);
    nav.go(AppView.editor);
  }

  void openActions(DesignModel d) {
    editor.setCurrent(d);
    nav.openSheet(const ActionsSheet());
  }

  void deleteSaved(int id) {
    session.deleteDesign(id);
    nav.closeSheet();
    toast('Design deleted');
  }

  void swapTemplate(DesignModel d) {
    if (session.state.isLocked(d)) {
      toast('Unlock this design first (1 coin)');
      return;
    }
    editor.swapTemplate(d);
  }

  void save() {
    final cur = editor.state.design;
    if (cur == null) return;
    final saved = cur.copyWith(mod: 'Just now');
    session.saveDesign(saved);
    editor.markSaved(saved, 'Saved just now');
    toast('Design saved successfully');
  }

  Future<void> removeBackground() async {
    final ok = await editor.removeBackground();
    if (ok) toast('Background removed');
  }

  // ---- studio ----------------------------------------------------------

  void publishDesign() {
    final form = studio.state.form;
    if (form.name.trim().isEmpty) {
      toast('Add a design name');
      return;
    }
    if (form.premium && !(form.cost > 0)) {
      toast('Enter the cost in ₹');
      return;
    }
    final editing = studio.state.editingId != 0;
    final id = editing
        ? studio.state.editingId
        : DateTime.now().millisecondsSinceEpoch;
    catalog.publish(form.toDesign(id).copyWith(status: 'Published'),
        replace: editing);
    toast(editing ? 'Design updated' : 'Design published');
    studio.finish();
  }

  void editTemplate(DesignModel d) => studio.edit(d);

  void deleteTemplate(int id) {
    catalog.delete(id);
    toast('Design deleted');
  }

  // ---- export / share --------------------------------------------------

  bool get _watermark => !session.state.premium;

  void openExport() => need(_openExport2);

  void _openExport2() {
    editor.setExportImage(null);
    nav.openSheet(const ExportSheet());
    regenerateExport();
  }

  /// "Download & Share" in the share sheet.
  void downloadAndShare() {
    final cur = editor.state.design;
    if (cur == null) return;
    editor.setFileName(cur.name.toLowerCase().replaceAll(' ', '_'));
    openExport();
  }

  Future<void> regenerateExport() async {
    final cur = editor.state.design;
    if (cur == null) return;
    final token = ++_exportToken;
    try {
      final bytes = await exporter.renderJpeg(cur,
          quality: editor.state.quality, watermark: _watermark);
      if (token == _exportToken) editor.setExportImage(bytes);
    } catch (e) {
      if (token == _exportToken) {
        nav.openSheet(const ErrorSheet('Export error'));
      }
    }
  }

  void setExportQuality(double quality) {
    editor.setQuality(quality);
    editor.setExportImage(null);
    regenerateExport();
  }

  /// "Download JPG": saves the file and opens the share sheet.
  Future<void> download() async {
    if (!session.state.signedIn) {
      _pending = download;
      nav.openSheet(const RegisterSheet());
      return;
    }
    final cur = editor.state.design;
    if (cur == null) return;
    try {
      Uint8List? bytes = editor.state.exportImage;
      bytes ??= await exporter.renderJpeg(cur,
          quality: editor.state.quality, watermark: _watermark);
      final name = editor.state.fileName;
      await _saveAndShare(bytes, name);
      editor.markCompleted();
      toast('Downloaded $name.jpg');
    } catch (e) {
      nav.openSheet(const ErrorSheet('Export error'));
    }
  }

  /// Download straight from a template's detail page (`dlT`).
  void downloadTemplate(int id) => need(() async {
        final d = catalog.state.byId(id);
        if (d == null) return;
        try {
          final bytes = await exporter.renderJpeg(d,
              quality: .92, watermark: _watermark);
          final name = d.name.toLowerCase().replaceAll(' ', '_');
          editor.setFileName(name);
          editor.setExportImage(bytes);
          await _saveAndShare(bytes, name);
          nav.openSheet(const DownloadedSheet());
        } catch (e) {
          nav.openSheet(const ErrorSheet('Export error'));
        }
      });

  Future<void> _saveAndShare(Uint8List bytes, String name) async {
    final path = await exporter.save(bytes, name);
    try {
      await exporter.shareFile(path);
    } catch (_) {
      // Saving succeeded; the share sheet is a convenience.
    }
  }

  Future<void> copyLink(DesignModel d) async {
    try {
      await Clipboard.setData(ClipboardData(text: shareLinkFor(d)));
    } catch (_) {}
    toast('Link copied');
  }

  Future<void> shareLink(DesignModel d) async {
    try {
      await Share.share(shareLinkFor(d));
    } catch (_) {
      await copyLink(d);
    }
  }

  Future<void> shareSharedView(DesignModel d) async {
    try {
      await Share.share(d.name, subject: d.name);
    } catch (_) {
      toast('Link copied');
    }
  }

  void dispose() => toasts.dispose();
}

extension AppControllerContext on BuildContext {
  AppController get app => read<AppController>();
}

/// Elements added from the editor's "Elements" / "Text" tools.
class NewElements {
  const NewElements._();

  static const heading = DesignElement.text(
      x: 8,
      y: 44,
      w: 84,
      text: 'Your heading',
      size: 40,
      color: Color(0xFFFFFFFF),
      bold: true);
  static const subtitle = DesignElement.text(
      x: 8,
      y: 44,
      w: 84,
      text: 'Add a subtitle',
      size: 22,
      color: Color(0xFFFFFFFF));
  static const circle = DesignElement.shape(
      x: 30,
      y: 30,
      w: 30,
      h: 30,
      fill: Color(0xFFFDE68A),
      shape: ShapeStyle.ellipse);
  static const square = DesignElement.shape(
      x: 30, y: 30, w: 30, h: 30, fill: Color(0xFFFDE68A));
  static const bar = DesignElement.shape(
      x: 20,
      y: 40,
      w: 60,
      h: 12,
      fill: Color(0xFFFDE68A),
      shape: ShapeStyle.pill);
}
