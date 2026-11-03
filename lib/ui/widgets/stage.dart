import 'package:flutter/material.dart';
import '../../core/theme/palette.dart';

/// `.stage`: the area that centres the design canvas on a checkerboard
/// (`min(90cqw, 90cqh)` square). [builder] receives the canvas side length.
class Stage extends StatelessWidget {
  const Stage({
    super.key,
    required this.builder,
    this.checkerboard = true,
    this.canvasRadius = 0,
    this.onLayout,
  });

  final Widget Function(BuildContext context, double side) builder;
  final bool checkerboard;
  final double canvasRadius;

  /// Reports the canvas side and its top-left offset inside the stage.
  final void Function(double side, Offset origin)? onLayout;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return LayoutBuilder(builder: (context, c) {
      final side = (c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight) * .9;
      onLayout?.call(
          side, Offset((c.maxWidth - side) / 2, (c.maxHeight - side) / 2));
      final canvas = Container(
        width: side,
        height: side,
        decoration: BoxDecoration(
          boxShadow: pal.sh,
          borderRadius:
              canvasRadius > 0 ? BorderRadius.circular(canvasRadius) : null,
        ),
        child: canvasRadius > 0
            ? ClipRRect(
                borderRadius: BorderRadius.circular(canvasRadius),
                child: builder(context, side))
            : builder(context, side),
      );
      return CustomPaint(
        painter: checkerboard ? _Checker(pal.pl, pal.bg) : null,
        child: SizedBox.expand(child: Center(child: canvas)),
      );
    });
  }
}

/// `repeating-conic-gradient(pl 0 25%, bg 0 50%) 0 0 / 20px 20px`
/// → a checkerboard of 10px squares.
class _Checker extends CustomPainter {
  _Checker(this.a, this.b);

  final Color a;
  final Color b;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = b);
    final paint = Paint()..color = a;
    for (var y = 0.0; y < size.height; y += 20) {
      for (var x = 0.0; x < size.width; x += 20) {
        canvas.drawRect(Rect.fromLTWH(x + 10, y, 10, 10), paint);
        canvas.drawRect(Rect.fromLTWH(x, y + 10, 10, 10), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_Checker old) => old.a != a || old.b != b;
}
