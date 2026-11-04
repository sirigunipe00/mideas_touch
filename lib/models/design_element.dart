import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

enum ElementKind { text, shape, image }

enum ShapeStyle { rect, ellipse, pill }

/// One layer on a design canvas (the artifact's `{k:"t"|"s"|"i", ...}`).
///
/// All geometry is expressed in percent of the (square) canvas, exactly as in
/// the original data: `x`, `y`, `w` (and `h` for shapes) are percentages, `s`
/// is the font size on a virtual 400px canvas and `r` is the rotation in
/// degrees.
@immutable
class DesignElement {
  const DesignElement({
    required this.kind,
    required this.x,
    required this.y,
    required this.w,
    this.h = 0,
    this.r = 0,
    this.text = '',
    this.font = 'Poppins',
    this.size = 20,
    this.color = const Color(0xFFFFFFFF),
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.align = TextAlign.center,
    this.fill = const Color(0xFFFDE68A),
    this.shape = ShapeStyle.rect,
    this.emoji = '',
    this.photo = false,
    this.image,
  });

  const DesignElement.text({
    required double x,
    required double y,
    required double w,
    required String text,
    String font = 'Poppins',
    required double size,
    required Color color,
    bool bold = false,
    TextAlign align = TextAlign.center,
  }) : this(
            kind: ElementKind.text,
            x: x,
            y: y,
            w: w,
            text: text,
            font: font,
            size: size,
            color: color,
            bold: bold,
            align: align);

  const DesignElement.shape({
    required double x,
    required double y,
    required double w,
    required double h,
    required Color fill,
    ShapeStyle shape = ShapeStyle.rect,
  }) : this(
            kind: ElementKind.shape,
            x: x,
            y: y,
            w: w,
            h: h,
            fill: fill,
            shape: shape);

  const DesignElement.image({
    required double x,
    required double y,
    required double w,
    required String emoji,
    bool photo = false,
    Uint8List? image,
  }) : this(
            kind: ElementKind.image,
            x: x,
            y: y,
            w: w,
            emoji: emoji,
            photo: photo,
            image: image);

  final ElementKind kind;
  final double x;
  final double y;
  final double w;
  final double h;
  final double r;
  final String text;
  final String font;
  final double size;
  final Color color;
  final bool bold;
  final bool italic;
  final bool underline;
  final TextAlign align;
  final Color fill;
  final ShapeStyle shape;
  final String emoji;
  final bool photo;

  /// Uploaded picture (replaces the emoji when present).
  final Uint8List? image;

  bool get isText => kind == ElementKind.text;
  bool get isShape => kind == ElementKind.shape;
  bool get isImage => kind == ElementKind.image;

  int get lineCount => text.split('\n').length;

  /// Height in percent of the canvas, as laid out by the artifact's CSS
  /// (text: `lines × size × 1.15`, images are square, shapes use `h`).
  double get heightPercent {
    switch (kind) {
      case ElementKind.text:
        return lineCount * size / 400 * 1.15 * 100;
      case ElementKind.shape:
        return h;
      case ElementKind.image:
        return w;
    }
  }

  DesignElement copyWith({
    double? x,
    double? y,
    double? w,
    double? h,
    double? r,
    String? text,
    String? font,
    double? size,
    Color? color,
    bool? bold,
    bool? italic,
    bool? underline,
    TextAlign? align,
    Color? fill,
    ShapeStyle? shape,
    String? emoji,
    bool? photo,
    Uint8List? image,
    bool clearImage = false,
  }) {
    return DesignElement(
      kind: kind,
      x: x ?? this.x,
      y: y ?? this.y,
      w: w ?? this.w,
      h: h ?? this.h,
      r: r ?? this.r,
      text: text ?? this.text,
      font: font ?? this.font,
      size: size ?? this.size,
      color: color ?? this.color,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      align: align ?? this.align,
      fill: fill ?? this.fill,
      shape: shape ?? this.shape,
      emoji: emoji ?? this.emoji,
      photo: photo ?? this.photo,
      image: clearImage ? null : (image ?? this.image),
    );
  }

  // ---- persistence (user_designs.elements) --------------------------------
  // Uploaded picture bytes are not part of the JSON.

  /// `#rrggbb`, or `#aarrggbb` when the colour is translucent.
  static String _hex(Color c) => c.alpha == 255
      ? '#${(c.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}'
      : '#${c.value.toRadixString(16).padLeft(8, '0')}';

  static Color _color(Object? v, Color fallback) {
    if (v is! String) return fallback;
    final h = v.replaceAll('#', '');
    final n = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
    return n == null ? fallback : Color(n);
  }

  static double _num(Object? v, double fallback) =>
      v is num ? v.toDouble() : fallback;

  Map<String, Object?> toJson() => {
        'kind': kind.name,
        'x': x,
        'y': y,
        'w': w,
        'h': h,
        'r': r,
        'text': text,
        'font': font,
        'size': size,
        'color': _hex(color),
        'bold': bold,
        'italic': italic,
        'underline': underline,
        'align': align.name,
        'fill': _hex(fill),
        'shape': shape.name,
        'emoji': emoji,
        'photo': photo,
      };

  factory DesignElement.fromJson(Map<String, dynamic> j) {
    final kind = ElementKind.values.asNameMap()[j['kind']] ?? ElementKind.text;
    return DesignElement(
      kind: kind,
      x: _num(j['x'], 0),
      y: _num(j['y'], 0),
      w: _num(j['w'], 30),
      h: _num(j['h'], 0),
      r: _num(j['r'], 0),
      text: (j['text'] as String?) ?? '',
      font: (j['font'] as String?) ?? 'Poppins',
      size: _num(j['size'], 20),
      color: _color(j['color'], const Color(0xFFFFFFFF)),
      bold: j['bold'] == true,
      italic: j['italic'] == true,
      underline: j['underline'] == true,
      align: TextAlign.values.asNameMap()[j['align']] ?? TextAlign.center,
      fill: _color(j['fill'], const Color(0xFFFDE68A)),
      shape: ShapeStyle.values.asNameMap()[j['shape']] ?? ShapeStyle.rect,
      emoji: (j['emoji'] as String?) ?? '',
      photo: j['photo'] == true,
    );
  }
}
