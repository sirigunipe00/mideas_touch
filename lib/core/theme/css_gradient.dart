import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';

/// A linear gradient that follows the CSS `linear-gradient(<angle>, ...)`
/// geometry exactly: the gradient line passes through the centre of the box,
/// at the given angle (0deg = up, 90deg = right), and is long enough for the
/// corners to land on the 0% / 100% colour stops.
class CssLinearGradient extends LinearGradient {
  const CssLinearGradient(this.angleDeg, List<Color> colors,
      [List<double>? stops])
      : super(colors: colors, stops: stops);

  final double angleDeg;

  @override
  Shader createShader(Rect rect, {ui.TextDirection? textDirection}) {
    final a = angleDeg * math.pi / 180;
    final dx = math.sin(a);
    final dy = -math.cos(a);
    final len = (rect.width * dx).abs() + (rect.height * dy).abs();
    final c = rect.center;
    final start = Offset(c.dx - dx * len / 2, c.dy - dy * len / 2);
    final end = Offset(c.dx + dx * len / 2, c.dy + dy * len / 2);
    return ui.Gradient.linear(start, end, colors, stops);
  }

  @override
  CssLinearGradient scale(double factor) => this;

  LinearGradient withOpacity(double opacity) => CssLinearGradient(angleDeg,
      colors.map((c) => c.withOpacity(c.opacity * opacity)).toList(), stops);
}
