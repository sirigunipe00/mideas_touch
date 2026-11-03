import 'package:flutter/material.dart';

/// The artifact's inline SVG coin, drawn with its original 24×24 viewBox.
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: const _CoinPainter());
}

class _CoinPainter extends CustomPainter {
  const _CoinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24);
    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFF0A0), Color(0xFFFFC928), Color(0xFFC88700)],
        stops: [0, .45, 1],
      ).createShader(const Rect.fromLTWH(0, 0, 24, 24));
    canvas.drawCircle(const Offset(12, 12), 11, fill);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFFA87000);
    canvas.drawCircle(const Offset(12, 12), 11, stroke);
    stroke.color = const Color(0xFFB37A00);
    canvas.drawCircle(const Offset(12, 12), 7.6, stroke);
    final star = Path()
      ..moveTo(12, 7.2)
      ..lineTo(13.4, 10.2)
      ..lineTo(16.7, 10.6)
      ..lineTo(14.3, 12.9)
      ..lineTo(14.9, 16.1)
      ..lineTo(12, 14.5)
      ..lineTo(9.1, 16.1)
      ..lineTo(9.7, 12.9)
      ..lineTo(7.3, 10.6)
      ..lineTo(10.6, 10.2)
      ..close();
    canvas.drawPath(star, Paint()..color = const Color(0xFFFFF3B0));
    canvas.drawPath(
        star,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .6
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFFB37A00));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Text that swaps every 🪙 for the artifact's coin icon (the artifact does
/// this globally in `R()`).
class CoinText extends StatelessWidget {
  const CoinText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.coinSize = 16,
  });

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final double coinSize;

  @override
  Widget build(BuildContext context) {
    if (!data.contains('🪙')) {
      return Text(data,
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
          softWrap: softWrap);
    }
    final parts = data.split('🪙');
    return Text.rich(
      TextSpan(children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0)
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: Transform.translate(
                  offset: const Offset(0, 3), child: CoinIcon(size: coinSize)),
            ),
          if (parts[i].isNotEmpty) TextSpan(text: parts[i]),
        ]
      ]),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
    );
  }
}
