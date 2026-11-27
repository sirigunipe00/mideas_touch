import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:image_background_remover/image_background_remover.dart';

/// Removes the background from any photo, the same way a cutout tool does:
/// the subject stays, everything behind it becomes transparent.
///
/// Runs an on-device segmentation model (people, products, animals, objects).
/// Call [ensureReady] once at startup so the first cutout does not wait on
/// model load.
class BackgroundRemoval {
  BackgroundRemoval._();

  static Future<void>? _ready;

  static Future<void> ensureReady() {
    return _ready ??= BackgroundRemover.instance.initializeOrt();
  }

  /// Returns a transparent PNG. Throws if the picture cannot be cut out.
  static Future<Uint8List> remove(Uint8List bytes) async {
    await ensureReady();
    final cutout = await BackgroundRemover.instance.removeBg(
      bytes,
      // Slightly below 0.5 so hair, hands and objects touching the subject
      // stay in, matching a full cutout rather than a hard silhouette.
      threshold: 0.42,
      smoothMask: true,
      enhanceEdges: true,
    );
    try {
      final data = await cutout.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw StateError('Could not encode the cutout.');
      }
      return data.buffer.asUint8List();
    } finally {
      cutout.dispose();
    }
  }
}
