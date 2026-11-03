import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import '../../models/design_element.dart';
import '../../models/design_model.dart';
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
    Canvas canvas, double n, DesignModel design, ImageLookup images) {
  _paintBackground(canvas, n, design, images);
  for (final e in design.els) {
    _paintElement(canvas, n, e, images);
  }
}

void _paintBackground(
    Canvas canvas, double n, DesignModel d, ImageLookup images) {
  final rect = Rect.fromLTWH(0, 0, n, n);
  canvas.save();
  canvas.clipRect(rect);
  final bi = images(d.bi);
  if (bi != null) {
    _drawCover(canvas, bi, rect);
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

void _drawCover(Canvas canvas, ui.Image img, Rect dst) {
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
      Paint()..filterQuality = FilterQuality.medium);
}

void _paintElement(
    Canvas canvas, double n, DesignElement e, ImageLookup images) {
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
      _paintImage(canvas, e, box.width, images);
      break;
  }
  canvas.restore();
}

void _paintText(Canvas canvas, double n, DesignElement e, double boxWidth) {
  final fs = e.size * n / 400;
  final style = TextStyle(
    fontFamily: e.font,
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
    case ShapeStyle.rect:
      canvas.drawRect(local, paint);
      break;
    case ShapeStyle.ellipse:
      canvas.drawOval(local, paint);
      break;
    case ShapeStyle.pill:
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              local, Radius.circular(math.min(box.width, box.height) / 2)),
          paint);
      break;
  }
}

void _paintImage(
    Canvas canvas, DesignElement e, double w, ImageLookup images) {
  final local = Rect.fromLTWH(0, 0, w, w);
  final rr = RRect.fromRectAndRadius(local, Radius.circular(w * .06));
  final uploaded = images(e.image);
  final hasUpload = e.image != null;

  // Photo card: `box-shadow: 0 4px 14px rgba(0,0,0,.25)`; plain images get a
  // `drop-shadow(0 6px 8px rgba(0,0,0,.3))` instead.
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
  } else if (hasUpload) {
    canvas.drawRRect(
        rr.shift(const Offset(0, 6)),
        Paint()
          ..color = const Color.fromRGBO(0, 0, 0, .3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
  }

  if (hasUpload) {
    if (uploaded != null) {
      canvas.save();
      canvas.clipRRect(rr);
      _drawCover(canvas, uploaded, local);
      canvas.restore();
    }
    return;
  }

  final tp = TextPainter(
    text: TextSpan(
      text: e.emoji,
      style: TextStyle(
        fontSize: w * .62,
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
  tp.paint(canvas, Offset((w - tp.width) / 2, (w - tp.height) / 2));
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

/// Free-download watermark: the tiled diagonal text and the corner badge
/// (see `ex()` in the artifact).
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

  canvas.saveLayer(Rect.fromLTWH(0, 0, n, n),
      Paint()..color = const Color.fromRGBO(255, 255, 255, .3));
  canvas.translate(n / 2, n / 2);
  canvas.rotate(-math.pi / 6);
  final tile = tp('Midas’s Touch', 56, FontWeight.w700, const Color(0xFFFFFFFF),
      shadows: const [
        Shadow(color: Color.fromRGBO(0, 0, 0, .55), blurRadius: 6)
      ]);
  var row = 0;
  for (double y = -n; y <= n; y += 260, row++) {
    for (double x = -n; x <= n; x += 440) {
      final cx = x + (row.isOdd ? 220 : 0);
      tile.paint(canvas, Offset(cx - tile.width / 2, y - tile.height / 2));
    }
  }
  canvas.restore();

  canvas.save();
  canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(n - 400, n - 84, 370, 56), const Radius.circular(28)),
      Paint()..color = const Color.fromRGBO(0, 0, 0, .55));
  final badge = tp('Made with Midas’s Touch', 26, FontWeight.w600,
      const Color(0xFFEFBF05));
  badge.paint(canvas,
      Offset(n - 215 - badge.width / 2, n - 56 - badge.height / 2));
  canvas.restore();
}
