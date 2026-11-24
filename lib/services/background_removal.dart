import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Local background removal for uploaded pictures.
///
/// Estimates the backdrop from edge / corner samples, floods similar edge
/// pixels inward, cleans fringe colour spill, then exports a transparent PNG.
class BackgroundRemoval {
  /// Returns a PNG with transparency. Throws if [bytes] cannot be decoded.
  static Future<Uint8List> remove(Uint8List bytes) async {
    final src = img.decodeImage(bytes);
    if (src == null) {
      throw StateError('Could not read the image.');
    }
    final rgba = src.numChannels == 4 ? src : src.convert(numChannels: 4);
    final w = rgba.width;
    final h = rgba.height;
    if (w < 2 || h < 2) {
      throw StateError('Image is too small.');
    }

    final bg = _estimateBackground(rgba);
    // Wider soft band so pale / grey paper backdrops are fully cleared.
    const hard = 48.0;
    const soft = 96.0;

    final mask = List<double>.filled(w * h, 1.0); // 1 = keep, 0 = remove
    final queue = <int>[];
    final seen = List<bool>.filled(w * h, false);

    void trySeed(int x, int y) {
      final i = y * w + x;
      if (seen[i]) return;
      final d = _distance(rgba.getPixel(x, y), bg);
      if (d <= soft) {
        seen[i] = true;
        queue.add(i);
        mask[i] = d <= hard ? 0.0 : 1.0 - ((d - hard) / (soft - hard));
      }
    }

    for (var x = 0; x < w; x++) {
      trySeed(x, 0);
      trySeed(x, h - 1);
    }
    for (var y = 0; y < h; y++) {
      trySeed(0, y);
      trySeed(w - 1, y);
    }

    while (queue.isNotEmpty) {
      final i = queue.removeLast();
      final x = i % w;
      final y = i ~/ w;
      for (final n in _neighbors(x, y, w, h)) {
        if (seen[n]) continue;
        final nx = n % w;
        final ny = n ~/ w;
        final d = _distance(rgba.getPixel(nx, ny), bg);
        if (d <= soft) {
          seen[n] = true;
          queue.add(n);
          mask[n] = d <= hard ? 0.0 : 1.0 - ((d - hard) / (soft - hard));
        }
      }
    }

    // Also punch out any leftover backdrop islands that match bg closely
    // (e.g. pale paper not connected to the edge after compression noise).
    for (var i = 0; i < mask.length; i++) {
      if (mask[i] >= 1) {
        final x = i % w;
        final y = i ~/ w;
        final d = _distance(rgba.getPixel(x, y), bg);
        if (d <= hard * 0.85) mask[i] = 0;
      }
    }

    final smoothed = _smoothMask(mask, w, h);
    final bgR = bg.r.toDouble();
    final bgG = bg.g.toDouble();
    final bgB = bg.b.toDouble();

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        final p = rgba.getPixel(x, y);
        var keep = smoothed[i];
        // Snap faint halo pixels fully off so no grey rectangle remains.
        if (keep < 0.22) keep = 0;
        if (keep > 0.92) keep = 1;

        var a = (p.a * keep).round().clamp(0, 255);
        var r = p.r.toDouble();
        var g = p.g.toDouble();
        var b = p.b.toDouble();

        // Colour decontamination: pull fringe pixels away from the backdrop
        // so anti-aliased edges do not leave a dark/grey outline.
        if (a > 0 && a < 255) {
          final t = a / 255.0;
          r = ((r - bgR * (1 - t)) / t).clamp(0, 255);
          g = ((g - bgG * (1 - t)) / t).clamp(0, 255);
          b = ((b - bgB * (1 - t)) / t).clamp(0, 255);
        }

        if (a < 12) {
          a = 0;
          r = 0;
          g = 0;
          b = 0;
        }

        rgba.setPixelRgba(x, y, r.round(), g.round(), b.round(), a);
      }
    }

    return Uint8List.fromList(img.encodePng(rgba));
  }

  static img.Color _estimateBackground(img.Image rgba) {
    final w = rgba.width;
    final h = rgba.height;
    final samples = <img.Color>[
      rgba.getPixel(0, 0),
      rgba.getPixel(w - 1, 0),
      rgba.getPixel(0, h - 1),
      rgba.getPixel(w - 1, h - 1),
      rgba.getPixel(w ~/ 2, 0),
      rgba.getPixel(w ~/ 2, h - 1),
      rgba.getPixel(0, h ~/ 2),
      rgba.getPixel(w - 1, h ~/ 2),
      rgba.getPixel(w ~/ 4, 0),
      rgba.getPixel((3 * w) ~/ 4, 0),
      rgba.getPixel(w ~/ 4, h - 1),
      rgba.getPixel((3 * w) ~/ 4, h - 1),
      rgba.getPixel(2, 2),
      rgba.getPixel(w - 3, 2),
      rgba.getPixel(2, h - 3),
      rgba.getPixel(w - 3, h - 3),
    ];
    var r = 0.0, g = 0.0, b = 0.0;
    for (final p in samples) {
      r += p.r;
      g += p.g;
      b += p.b;
    }
    final n = samples.length;
    return img.ColorRgba8(
        (r / n).round(), (g / n).round(), (b / n).round(), 255);
  }

  static double _distance(img.Color a, img.Color b) {
    final dr = (a.r - b.r).toDouble();
    final dg = (a.g - b.g).toDouble();
    final db = (a.b - b.b).toDouble();
    return math.sqrt(dr * dr + dg * dg + db * db);
  }

  static Iterable<int> _neighbors(int x, int y, int w, int h) sync* {
    if (x > 0) yield y * w + (x - 1);
    if (x + 1 < w) yield y * w + (x + 1);
    if (y > 0) yield (y - 1) * w + x;
    if (y + 1 < h) yield (y + 1) * w + x;
  }

  static List<double> _smoothMask(List<double> mask, int w, int h) {
    final out = List<double>.from(mask);
    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final i = y * w + x;
        var sum = 0.0;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            sum += mask[(y + dy) * w + (x + dx)];
          }
        }
        out[i] = sum / 9;
      }
    }
    return out;
  }
}
