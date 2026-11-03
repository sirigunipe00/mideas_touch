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
}
