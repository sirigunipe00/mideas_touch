import 'dart:math' as math;
import 'dart:ui';
import '../../models/design_element.dart';

enum HitMode { move, resize, rotate }

class Hit {
  const Hit(this.index, this.mode);
  final int index;
  final HitMode mode;
}

/// Pure geometry helpers for hit-testing and handle placement on the
/// editing canvas. Coordinates are in canvas pixels (`n` = canvas width).
class ElementGeometry {
  const ElementGeometry._();

  /// Diameter of the resize / rotate handles (`.rh`, `.ro` = 22px).
  static const handleSize = 22.0;

  /// Distance from the element's top edge to the rotate handle centre
  /// (`top:-34px` + half the 22px handle).
  static const rotateHandleOffset = 23.0;

  /// Extra finger-friendly slop around the handles when hit-testing.
  static const handleHitRadius = 18.0;

  static Rect boxOf(DesignElement e, double n) {
    final k = n / 100;
    return Rect.fromLTWH(
        e.x * k, e.y * k, e.w * k, e.heightPercent * k);
  }

  /// Converts a canvas point into the element's un-rotated local space
  /// (origin at the element's top-left corner).
  static Offset toLocal(DesignElement e, double n, Offset p) {
    final box = boxOf(e, n);
    final c = box.center;
    final a = -e.r * math.pi / 180;
    final d = p - c;
    final lx = d.dx * math.cos(a) - d.dy * math.sin(a);
    final ly = d.dx * math.sin(a) + d.dy * math.cos(a);
    return Offset(lx + box.width / 2, ly + box.height / 2);
  }

  static Hit? hitTest(
      List<DesignElement> els, double n, int selected, Offset p) {
    if (selected >= 0 && selected < els.length) {
      final e = els[selected];
      final box = boxOf(e, n);
      final l = toLocal(e, n, p);
      if ((l - Offset(box.width, box.height)).distance <= handleHitRadius) {
        return Hit(selected, HitMode.resize);
      }
      if ((l - Offset(box.width / 2, -rotateHandleOffset)).distance <=
          handleHitRadius) {
        return Hit(selected, HitMode.rotate);
      }
    }
    for (var i = els.length - 1; i >= 0; i--) {
      final e = els[i];
      final box = boxOf(e, n);
      final l = toLocal(e, n, p);
      if (l.dx >= 0 && l.dx <= box.width && l.dy >= 0 && l.dy <= box.height) {
        return Hit(i, HitMode.move);
      }
    }
    return null;
  }
}
