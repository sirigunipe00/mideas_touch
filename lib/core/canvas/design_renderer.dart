import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import '../../models/design_element.dart';
import '../../models/design_model.dart';
import '../fonts/google_fonts_service.dart';
import '../theme/css_gradient.dart';
import 'geometry.dart';

typedef ImageLookup = ui.Image? Function(Uint8List? bytes);

const _devanagari = ['Noto Sans Devanagari'];

/// Paints a [DesignModel] onto [canvas] in a square of side [n].
///
/// This reproduces the artifact's `.cv` markup: the two-circle gradient
/// background (`bgc`) and every element (`eh`), using the same percent based
/// geometry and the `cqw` font scaling (`size / 400 × canvas width`).
void paintDesign(
  Canvas canvas,
  double n,
  DesignModel design,
  ImageLookup images, {
  FilterQuality imageQuality = FilterQuality.medium,
}) {
  _paintBackground(canvas, n, design, images, imageQuality);
  // Published artwork (Storage JPG) already includes the base design. Locked
  // template layers must not be redrawn on top — that caused double text when
  // a creator changed a font (baked pixels + live TextPainter).
  final publishedArt = images(design.bi) != null ||
      (design.biPath != null && design.biPath!.isNotEmpty);
  for (final e in design.els) {
    if (publishedArt && e.locked) continue;
    _paintElement(canvas, n, e, images, imageQuality);
  }
}

void _paintBackground(
  Canvas canvas,
  double n,
  DesignModel d,
  ImageLookup images,
  FilterQuality imageQuality,
) {
  final rect = Rect.fromLTWH(0, 0, n, n);
  canvas.save();
  canvas.clipRect(rect);
  final bi = images(d.bi);
  if (bi != null) {
    _drawCover(canvas, bi, rect, imageQuality);
  } else {
    final paint = Paint()
      ..shader = CssLinearGradient(145, d.bg).createShader(rect);
    canvas.drawRect(rect, paint);
    canvas.drawCircle(Offset(n * .9, n * .05), n * .32,
        Paint()..color = const Color.fromRGBO(255, 255, 255, .16));
    canvas.drawCircle(Offset(n * .05, n * .95), n * .24,
        Paint()..color = const Color.fromRGBO(255, 255, 255, .10));
  }
  canvas.restore();
}

void _drawCover(
    Canvas canvas, ui.Image img, Rect dst, FilterQuality imageQuality) {
  final scale =
      math.max(dst.width / img.width, dst.height / img.height).toDouble();
  final w = img.width * scale;
  final h = img.height * scale;
  final target = Rect.fromLTWH(
      dst.left + (dst.width - w) / 2, dst.top + (dst.height - h) / 2, w, h);
  canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      target,
      Paint()
        ..filterQuality = imageQuality
        ..isAntiAlias = true);
}

void _paintElement(
  Canvas canvas,
  double n,
  DesignElement e,
  ImageLookup images,
  FilterQuality imageQuality,
) {
  final box = ElementGeometry.boxOf(e, n);
  canvas.save();
  canvas.translate(box.center.dx, box.center.dy);
  canvas.rotate(e.r * math.pi / 180);
  canvas.translate(-box.width / 2, -box.height / 2);
  switch (e.kind) {
    case ElementKind.text:
      _paintText(canvas, n, e, box.width);
      break;
    case ElementKind.shape:
      _paintShape(canvas, e, box);
      break;
    case ElementKind.image:
      _paintImage(canvas, e, box, images, imageQuality);
      break;
  }
  canvas.restore();
}

void _paintText(Canvas canvas, double n, DesignElement e, double boxWidth) {
  final fs = e.size * n / 400;
  final style = TextStyle(
    fontFamily: GoogleFontsService.resolve(e.font, bold: e.bold),
    fontFamilyFallback: _devanagari,
    fontSize: fs,
    fontWeight: e.bold ? FontWeight.w700 : FontWeight.w400,
    fontStyle: e.italic ? FontStyle.italic : FontStyle.normal,
    color: e.color,
    height: 1.15,
    leadingDistribution: TextLeadingDistribution.even,
    decoration: e.underline ? TextDecoration.underline : TextDecoration.none,
    decorationColor: e.color,
  );
  final lines = e.text.split('\n');
  for (var j = 0; j < lines.length; j++) {
    final tp = TextPainter(
      text: TextSpan(text: lines[j].isEmpty ? ' ' : lines[j], style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    double dx;
    if (tp.width > boxWidth) {
      dx = 0; // CSS start-aligns lines that overflow the box.
    } else if (e.align == TextAlign.left) {
      dx = 0;
    } else if (e.align == TextAlign.right) {
      dx = boxWidth - tp.width;
    } else {
      dx = (boxWidth - tp.width) / 2;
    }
    tp.paint(canvas, Offset(dx, j * fs * 1.15));
  }
}

void _paintShape(Canvas canvas, DesignElement e, Rect box) {
  final local = Rect.fromLTWH(0, 0, box.width, box.height);
  final paint = Paint()..color = e.fill;
  switch (e.shape) {
    case ShapeStyle.ellipse:
      canvas.drawOval(local, paint);
      break;
    case ShapeStyle.rect:
    case ShapeStyle.pill:
      // `corner` is % of the shorter side (0 = sharp, 50 = fully round).
      // Pills default to fully round when corner was never set.
      final maxR = math.min(box.width, box.height) / 2;
      final cornerPct = e.corner > 0
          ? e.corner
          : (e.shape == ShapeStyle.pill ? 50.0 : 0.0);
      final radius = maxR * (cornerPct.clamp(0, 50) / 50);
      if (radius <= 0) {
        canvas.drawRect(local, paint);
      } else {
        canvas.drawRRect(
            RRect.fromRectAndRadius(local, Radius.circular(radius)), paint);
      }
      break;
  }
}

void _paintImage(
  Canvas canvas,
  DesignElement e,
  Rect box,
  ImageLookup images,
  FilterQuality imageQuality,
) {
  final local = Rect.fromLTWH(0, 0, box.width, box.height);
  final radius = math.min(box.width, box.height) * .06;
  final rr = RRect.fromRectAndRadius(local, Radius.circular(radius));
  final uploaded = images(e.image);
  final hasUpload = e.image != null;

  // Photo-card chrome only while the original backdrop is still present.
  // After background removal there must be no rectangular shadow/halo.
  if (e.photo) {
    canvas.drawRRect(
        rr.shift(const Offset(0, 4)),
        Paint()
          ..color = const Color.fromRGBO(0, 0, 0, .25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
    if (!hasUpload) {
      canvas.drawRRect(
          rr,
          Paint()
            ..shader = const CssLinearGradient(
                135, [Color(0xFFFFFFFF), Color(0xFFFCF4D3)]).createShader(local));
    }
  }

  if (hasUpload) {
    if (uploaded != null) {
      canvas.save();
      // Keep rounded clip only for photo cards; cutouts need full transparency.
      if (e.photo) canvas.clipRRect(rr);
      _drawCover(canvas, uploaded, local, imageQuality);
      canvas.restore();
    }
    return;
  }

  final side = math.min(box.width, box.height);
  final tp = TextPainter(
    text: TextSpan(
      text: e.emoji,
      style: TextStyle(
        fontSize: side * .62,
        height: 1,
        leadingDistribution: TextLeadingDistribution.even,
        color: const Color(0xFF000000),
        shadows: e.photo
            ? null
            : const [
                Shadow(
                    color: Color.fromRGBO(0, 0, 0, .3),
                    offset: Offset(0, 6),
                    blurRadius: 8)
              ],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(
      canvas,
      Offset((box.width - tp.width) / 2, (box.height - tp.height) / 2));
}

/// Editing chrome: selection outline, resize and rotate handles.
void paintSelection(Canvas canvas, double n, DesignElement e) {
  final box = ElementGeometry.boxOf(e, n);
  canvas.save();
  canvas.translate(box.center.dx, box.center.dy);
  canvas.rotate(e.r * math.pi / 180);
  canvas.translate(-box.width / 2, -box.height / 2);
  final local = Rect.fromLTWH(0, 0, box.width, box.height);
  canvas.drawRect(
      local.inflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFEFBF05));
  void handle(Offset c) {
    const r = ElementGeometry.handleSize / 2;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFFFFFFF));
    canvas.drawCircle(
        c,
        r - 1.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFFEFBF05));
  }

  handle(Offset(box.width, box.height));
  handle(Offset(box.width / 2, -ElementGeometry.rotateHandleOffset));
  canvas.restore();
}

/// The red vertical centre guide (`.gd`).
void paintGuide(Canvas canvas, double n) {
  canvas.drawRect(Rect.fromLTWH(n / 2, 0, 1, n),
      Paint()..color = const Color(0xFFED0707));
}

/// Free-download watermark: tiled diagonal text + corner badge.
void paintWatermark(Canvas canvas, double n) {
  TextPainter tp(String text, double size, FontWeight weight, Color color,
      {List<Shadow>? shadows}) {
    return TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: size,
              fontWeight: weight,
              color: color,
              height: 1,
              leadingDistribution: TextLeadingDistribution.even,
              shadows: shadows)),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  // Scale chrome with canvas size (1080 baseline → 2160 at 100% quality).
  final s = n / 1080;

  // Lighter diagonal watermark so the design stays readable.
  canvas.saveLayer(Rect.fromLTWH(0, 0, n, n),
      Paint()..color = const Color.fromRGBO(255, 255, 255, .14));
  canvas.translate(n / 2, n / 2);
  canvas.rotate(-math.pi / 6);
  final tile = tp('Midas’s Touch', 56 * s, FontWeight.w700, const Color(0xFFFFFFFF),
      shadows: [
        Shadow(
            color: const Color.fromRGBO(0, 0, 0, .28), blurRadius: 5 * s)
      ]);
  var row = 0;
  for (double y = -n; y <= n; y += 260 * s, row++) {
    for (double x = -n; x <= n; x += 440 * s) {
      final cx = x + (row.isOdd ? 220 * s : 0);
      tile.paint(canvas, Offset(cx - tile.width / 2, y - tile.height / 2));
    }
  }
  canvas.restore();

  canvas.save();
  canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(n - 400 * s, n - 84 * s, 370 * s, 56 * s),
          Radius.circular(28 * s)),
      Paint()..color = const Color.fromRGBO(0, 0, 0, .55));
  final badge = tp('Made with Midas’s Touch', 26 * s, FontWeight.w600,
      const Color(0xFFEFBF05));
  badge.paint(
      canvas,
      Offset(n - 215 * s - badge.width / 2, n - 56 * s - badge.height / 2));
  canvas.restore();
}
