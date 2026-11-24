import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
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

/// Renders designs to JPG files and hands them to the OS.
class ExportService {
  /// Baseline / mid export size. 100% quality uses [maxSize].
  static const int baseSize = 1080;
  static const int maxSize = 2160;
  static const String albumName = "Midas's Touch";

  /// Maps slider quality `0.5 … 1.0` → pixel size `1080 … 2160`.
  static int pixelSizeFor(double quality) {
    final t = ((quality - 0.5) / 0.5).clamp(0.0, 1.0);
    return (baseSize + (maxSize - baseSize) * t).round();
  }

  /// Maps slider quality `0.5 … 1.0` → JPEG quality `55 … 100`
  /// (low end is intentionally softer so the difference is visible).
  static int jpegQualityFor(double quality) {
    final t = ((quality - 0.5) / 0.5).clamp(0.0, 1.0);
    return (55 + (45 * t)).round().clamp(55, 100);
  }

  /// Renders [design] to a JPG. [quality] is `0.5 … 1.0` and controls both
  /// resolution and JPEG compression. Free downloads pass [watermark]: true.
  Future<Uint8List> renderJpeg(
    DesignModel design, {
    required double quality,
    bool watermark = false,
  }) async {
    final pictures = <Uint8List>[
      if (design.bi != null) design.bi!,
      for (final e in design.els)
        if (e.image != null) e.image!,
    ];
    await Future.wait(pictures.map(ImageStore.load));

    final size = pixelSizeFor(quality);
    final jpegQ = jpegQualityFor(quality);

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

    // Copy bytes for the isolate — the ByteData view is not transferable.
    final rgba = Uint8List.fromList(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    return compute(_encodeJpeg, _EncodeJob(rgba, size, jpegQ));
  }

  String _safeName(String name) {
    final cleaned =
        name.trim().replaceAll(RegExp(r'[^\w\-\u0900-\u097f]'), '_');
    return cleaned.isEmpty ? 'design' : cleaned;
  }

  /// Writes the JPG to a temp file (for sharing) and returns its path.
  Future<String> saveTemp(Uint8List bytes, String name) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_safeName(name)}.jpg');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// Saves the JPG into the device photo gallery / Photos library.
  Future<void> saveToGallery(Uint8List bytes, String name) async {
    // gal 2.1.x has no putImageBytes(name:); save via temp file so the
    // gallery entry keeps a readable filename.
    final path = await saveTemp(bytes, name);
    await Gal.putImage(path, album: albumName);
  }

  /// Opens the system share sheet so the user can send the file.
  Future<ShareResult> shareFile(String path) =>
      Share.shareXFiles([XFile(path, mimeType: 'image/jpeg')]);

  Future<ShareResult> shareText(String text, {String? subject}) =>
      Share.share(text, subject: subject);
}
