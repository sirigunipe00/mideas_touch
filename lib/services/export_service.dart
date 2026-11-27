import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/canvas/design_renderer.dart';
import '../core/canvas/image_store.dart';
import '../core/fonts/google_fonts_service.dart';
import '../models/design_model.dart';

class _EncodeJob {
  _EncodeJob(this.rgba, this.size, this.quality);
  final Uint8List rgba;
  final int size;
  final int quality;
}

class _UpscaleJob {
  _UpscaleJob(this.bytes, this.size, this.quality);
  final Uint8List bytes;
  final int size;
  final int quality;
}

/// Enlarges a published JPG with cubic filtering and saves a sharp JPEG.
Uint8List _upscaleJpeg(_UpscaleJob job) {
  final decoded = img.decodeImage(job.bytes);
  if (decoded == null) return job.bytes;
  final scale = math.max(job.size / decoded.width, job.size / decoded.height);
  final w = math.max(job.size, (decoded.width * scale).round());
  final h = math.max(job.size, (decoded.height * scale).round());
  final scaled = img.copyResize(
    decoded,
    width: w,
    height: h,
    interpolation: img.Interpolation.cubic,
  );
  final square = (scaled.width == job.size && scaled.height == job.size)
      ? scaled
      : img.copyCrop(
          scaled,
          x: ((scaled.width - job.size) / 2).round(),
          y: ((scaled.height - job.size) / 2).round(),
          width: job.size,
          height: job.size,
        );
  return Uint8List.fromList(img.encodeJpg(
    square,
    quality: job.quality,
    chroma: img.JpegChroma.yuv444,
  ));
}

Uint8List _encodeJpeg(_EncodeJob job) {
  final image = img.Image.fromBytes(
    width: job.size,
    height: job.size,
    bytes: job.rgba.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  // 4:4:4 keeps text edges sharp. 4:2:0 is what made exports look soft.
  return Uint8List.fromList(img.encodeJpg(
    image,
    quality: job.quality,
    chroma: img.JpegChroma.yuv444,
  ));
}

/// Renders designs to JPG files and hands them to the OS.
class ExportService {
  /// Lowest saved resolution. Sharp enough for a phone screen.
  static const int baseSize = 2160;
  /// 100% quality. Kept under 4K so the encode does not run out of memory.
  static const int highSize = 3840;
  static const String albumName = "Midas's Touch";

  /// Longest edge of the pictures already decoded for [design].
  static int sourceEdge(DesignModel design) {
    var edge = 0;
    void consider(Uint8List? bytes) {
      final image = ImageStore.peek(bytes);
      if (image == null) return;
      edge = math.max(edge, math.max(image.width, image.height));
    }

    consider(design.bi);
    for (final e in design.els) {
      consider(e.image);
    }
    return edge;
  }

  /// Maps slider quality `0.5 … 1.0` → pixel size `2160 … 3840`.
  ///
  /// A small published picture is never saved as-is. Both ends of the slider
  /// are high resolution; 100% is the larger file.
  static int pixelSizeFor(double quality, {int sourceEdge = 0}) {
    final t = ((quality - 0.5) / 0.5).clamp(0.0, 1.0);
    final low = math.max(baseSize, sourceEdge);
    final high = math.max(highSize, sourceEdge);
    return (low + (high - low) * t).round();
  }

  /// Maps slider quality `0.5 … 1.0` → JPEG quality `95 … 100`.
  static int jpegQualityFor(double quality) {
    final t = ((quality - 0.5) / 0.5).clamp(0.0, 1.0);
    return (95 + (5 * t)).round().clamp(95, 100);
  }

  /// True when the export is only the published picture (no layers to draw).
  static bool _backgroundOnly(DesignModel design, {required bool watermark}) {
    if (watermark || design.bi == null) return false;
    return design.els.isEmpty;
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
    // Exports must draw text in the chosen Google Font, not the fallback.
    await GoogleFontsService.ensureFor(design.els);

    final edge = sourceEdge(design);
    final size = pixelSizeFor(quality, sourceEdge: edge);
    final jpegQ = jpegQualityFor(quality);

    // Keep an already-large master file. A small published JPG is re-rendered
    // below so the gallery copy is not a few hundred pixels wide.
    final backgroundOnly =
        _backgroundOnly(design, watermark: watermark) && design.bi != null;
    if (backgroundOnly && edge >= size) {
      return design.bi!;
    }
    // Published artwork with nothing added on top: enlarge the file itself.
    // Drawing it through the small on-screen canvas was keeping the download soft.
    if (backgroundOnly && edge < size) {
      return compute(
          _upscaleJpeg, _UpscaleJob(design.bi!, size, jpegQ));
    }

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
        recorder, ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()));
    paintDesign(
      canvas,
      size.toDouble(),
      design,
      ImageStore.peek,
      imageQuality: ui.FilterQuality.high,
    );
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
