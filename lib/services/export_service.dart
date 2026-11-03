import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/canvas/design_renderer.dart';
import '../core/canvas/image_store.dart';
import '../models/design_model.dart';

class _EncodeJob {
  _EncodeJob(this.rgba, this.size, this.quality);
  final Uint8List rgba;
  final int size;
  final int quality;
}

Uint8List _encodeJpeg(_EncodeJob job) {
  final image = img.Image.fromBytes(
    width: job.size,
    height: job.size,
    bytes: job.rgba.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return Uint8List.fromList(img.encodeJpg(image, quality: job.quality));
}

/// Renders designs to 1080×1080 JPG files and hands them to the OS.
class ExportService {
  static const int size = 1080;

  /// Renders [design] (the artifact's `ex()`): optionally with the free-plan
  /// watermark. [quality] is `0.5 … 1.0`.
  Future<Uint8List> renderJpeg(
    DesignModel design, {
    required double quality,
    required bool watermark,
  }) async {
    final pictures = <Uint8List>[
      if (design.bi != null) design.bi!,
      for (final e in design.els)
        if (e.image != null) e.image!,
    ];
    await Future.wait(pictures.map(ImageStore.load));

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
        recorder, ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()));
    paintDesign(canvas, size.toDouble(), design, ImageStore.peek);
    if (watermark) paintWatermark(canvas, size.toDouble());
    final picture = recorder.endRecording();
    final raster = await picture.toImage(size, size);
    final data = await raster.toByteData(format: ui.ImageByteFormat.rawRgba);
    raster.dispose();
    picture.dispose();
    if (data == null) throw StateError('Could not render the design.');
    final job = _EncodeJob(
        data.buffer.asUint8List(), size, (quality * 100).round());
    return compute(_encodeJpeg, job);
  }

  /// Saves the JPG into the app's documents folder and returns its path.
  Future<String> save(Uint8List bytes, String name) async {
    final dir = await getApplicationDocumentsDirectory();
    final cleaned =
        name.trim().replaceAll(RegExp(r'[^\w\-\u0900-\u097f]'), '_');
    final file =
        File('${dir.path}/${cleaned.isEmpty ? 'design' : cleaned}.jpg');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// Opens the system share sheet so the user can store / send the file.
  Future<void> shareFile(String path) =>
      Share.shareXFiles([XFile(path, mimeType: 'image/jpeg')]);

  Future<void> shareText(String text, {String? subject}) =>
      Share.share(text, subject: subject);
}
