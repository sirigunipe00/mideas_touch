import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/design_element.dart';

/// Every Google Font, loaded on demand.
///
/// The full catalogue is listed offline. A family is downloaded the first time
/// it is used, then cached on the device. Canvases listen to [revision] and
/// repaint once a font has arrived.
class GoogleFontsService {
  GoogleFontsService._();

  /// Bumped whenever a font finishes loading.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Families shipped inside the app (see pubspec assets). Never downloaded.
  static const Set<String> bundled = {
    'Poppins',
    'Playfair Display',
    'Pacifico',
    'Bebas Neue',
    'Noto Sans Devanagari',
    'Hind',
    'Baloo 2',
  };

  static final Set<String> _catalogue = GoogleFonts.asMap().keys.toSet();
  static final List<String> _sorted = _catalogue.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  /// Registered family name per "family|bold" key.
  static final Map<String, String> _registered = {};

  /// Every Google Font family, A–Z.
  static List<String> get families => _sorted;

  static bool isGoogle(String family) =>
      !bundled.contains(family) && _catalogue.contains(family);

  static String _key(String family, bool bold) => '$family|${bold ? 1 : 0}';

  /// Name to hand to a TextStyle. Falls back to [family] until it has loaded.
  static String resolve(String family, {bool bold = false}) {
    if (!isGoogle(family)) return family;
    return _registered[_key(family, bold)] ?? family;
  }

  /// Starts downloading [family] (once) and bumps [revision] when it is ready.
  static Future<void> ensure(String family, {bool bold = false}) async {
    if (!isGoogle(family)) return;
    final key = _key(family, bold);
    if (_registered.containsKey(key)) return;
    final style = GoogleFonts.getFont(
      family,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
    );
    // Store the name before awaiting so repeat calls do not start a second load.
    _registered[key] = style.fontFamily ?? family;
    try {
      await GoogleFonts.pendingFonts();
    } catch (_) {
      // Offline or failed download: the text keeps the fallback typeface.
    }
    revision.value++;
  }

  /// Makes sure every Google Font used by [els] is ready.
  static Future<void> ensureFor(Iterable<DesignElement> els) async {
    final pending = <Future<void>>[];
    for (final e in els) {
      if (e.isText) pending.add(ensure(e.font, bold: e.bold));
    }
    await Future.wait(pending);
  }
}
