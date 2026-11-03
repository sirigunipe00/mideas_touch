import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/theme/palette.dart';
import 'coin.dart';

const FontWeight kSemi = FontWeight.w600;
const FontWeight kBold = FontWeight.w700;

/// Plain tap target without Material ripple (the artifact has none).
class Tap extends StatelessWidget {
  const Tap({super.key, required this.onTap, required this.child, this.label});

  final VoidCallback? onTap;
  final Widget child;
  final String? label;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
            behavior: HitTestBehavior.opaque, onTap: onTap, child: child),
      );
}

enum BtnStyle { primary, ghost, danger }

/// `.btn`, `.btn.g`, `.btn.r`, with `.s` (small) and `.w` (wide) modifiers.
class AppButton extends StatelessWidget {
  const AppButton(
    this.label, {
    super.key,
    required this.onTap,
    this.style = BtnStyle.primary,
    this.small = false,
    this.wide = false,
    this.background,
    this.foreground,
    this.fontSize,
  });

  final String label;
  final VoidCallback? onTap;
  final BtnStyle style;
  final bool small;
  final bool wide;
  final Color? background;
  final Color? foreground;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final bg = background ??
        switch (style) {
          BtnStyle.primary => pal.p,
          BtnStyle.ghost => pal.pl2,
          BtnStyle.danger => Brand.red,
        };
    final fg = foreground ??
        switch (style) {
          BtnStyle.primary => pal.pt,
          BtnStyle.ghost => pal.tx,
          BtnStyle.danger => Colors.white,
        };
    final enabled = onTap != null;
    final fs = fontSize ?? (small ? 12.0 : 13.3333);
    final content = Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 12 : 18, vertical: small ? 7 : 12),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(small ? 10 : 14)),
      alignment: wide ? Alignment.center : null,
      child: CoinText(label,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: fg,
              fontSize: fs,
              height: 1.5,
              leadingDistribution: TextLeadingDistribution.even),
          coinSize: 16),
    );
    return Opacity(
      opacity: enabled ? 1 : .4,
      child: Tap(
          onTap: onTap,
          label: label,
          child: wide
              ? SizedBox(width: double.infinity, child: content)
              : content),
    );
  }
}

/// `.ib`: a bordered square icon button (min 40×40).
class IconBox extends StatelessWidget {
  const IconBox({
    super.key,
    required this.child,
    required this.onTap,
    this.on = false,
    this.dim = false,
    this.background,
    this.foreground,
    this.borderless = false,
    this.label,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool on;
  final bool dim;
  final Color? background;
  final Color? foreground;
  final bool borderless;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Opacity(
      opacity: dim ? .35 : 1,
      child: Tap(
        onTap: onTap,
        label: label,
        child: Container(
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background ?? (on ? pal.pl2 : pal.c),
            borderRadius: BorderRadius.circular(10),
            border: borderless
                ? null
                : Border.all(color: on ? pal.p : pal.ln, width: 1),
          ),
          child: DefaultTextStyle.merge(
              style: TextStyle(color: foreground ?? pal.tx),
              child: child),
        ),
      ),
    );
  }
}

/// `.tag`: a small pill label.
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 1),
        decoration: BoxDecoration(
            color: context.pal.pl2, borderRadius: BorderRadius.circular(99)),
        child: CoinText(text, style: const TextStyle(fontSize: 11)),
      );
}

/// `h2`: section heading with the artifact's margins.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.top = 20});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(16, top, 16, 10),
        child: CoinText(text,
            style: const TextStyle(fontSize: 17, fontWeight: kBold)),
      );
}

/// `label`: small muted form label.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 4),
        child: Text(text,
            style: TextStyle(fontSize: 11, color: context.pal.mu)),
      );
}

/// `.seg`: segmented control used for tab strips.
class Segmented extends StatelessWidget {
  const Segmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 12),
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: pal.pl, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        for (final o in options)
          Expanded(
            child: Tap(
              onTap: () => onChanged(o),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: selected == o ? pal.p : null,
                    borderRadius: BorderRadius.circular(10)),
                child: Text(o,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected == o ? kSemi : FontWeight.w400,
                        color: selected == o ? pal.pt : pal.tx)),
              ),
            ),
          ),
      ]),
    );
  }
}

/// `.ch a`: one category chip.
class CategoryChip extends StatelessWidget {
  const CategoryChip(this.label, {super.key, this.on = false, this.onTap});

  final String label;
  final bool on;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Tap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: on ? pal.p : pal.c,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: on ? pal.p : pal.ln),
        ),
        child: Text(label,
            maxLines: 1,
            style: TextStyle(fontSize: 13, color: on ? pal.pt : pal.tx)),
      ),
    );
  }
}

/// `.li`: list row card.
class ListCard extends StatelessWidget {
  const ListCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: pal.c, borderRadius: BorderRadius.circular(16), boxShadow: pal.sh),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          children[i],
        ]
      ]),
    );
  }
}

/// `.mi`: a menu / info row.
class MenuRow extends StatelessWidget {
  const MenuRow({
    super.key,
    required this.child,
    this.trailing,
    this.onTap,
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 8),
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.decorationOverride,
  });

  final Widget child;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsets margin;
  final EdgeInsets padding;
  final BoxDecoration? decorationOverride;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      margin: margin,
      padding: padding,
      decoration: decorationOverride ??
          BoxDecoration(
              color: context.pal.c, borderRadius: BorderRadius.circular(14)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: child),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
    return onTap == null ? row : Tap(onTap: onTap, child: row);
  }
}

/// `.empty`: dashed empty-state card.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.buttonLabel,
    this.onButton,
    this.margin = const EdgeInsets.all(16),
  });

  final String title;
  final String message;
  final String? buttonLabel;
  final VoidCallback? onButton;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      margin: margin,
      width: double.infinity,
      child: CustomPaint(
        painter: _DashedRRect(pal.ln, pal.c, 20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: kSemi)),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.2),
              child: Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: pal.mu)),
            ),
            if (buttonLabel != null) ...[
              const SizedBox(height: 12),
              AppButton(buttonLabel!, onTap: onButton),
            ],
          ]),
        ),
      ),
    );
  }
}

class _DashedRRect extends CustomPainter {
  _DashedRRect(this.line, this.fill, this.radius);

  final Color line;
  final Color fill;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(.5), Radius.circular(radius));
    canvas.drawRRect(rrect, Paint()..color = fill);
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = line;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 3, metric.length)), paint);
        d += 6;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRect old) =>
      old.line != line || old.fill != fill || old.radius != radius;
}

/// `.sk`: shimmering loading placeholder.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, required this.height, this.radius = 18});

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(
              painter: _SkeletonPainter(pal.ln, pal.pl, _c.value)),
        ),
      ),
    );
  }
}

class _SkeletonPainter extends CustomPainter {
  _SkeletonPainter(this.a, this.b, this.t);

  final Color a;
  final Color b;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final shader = ui.Gradient.linear(
      Offset(2 * w * t, 0),
      Offset(2 * w * t + 2 * w, 0),
      [a, b, a],
      const [0, .5, 1],
      TileMode.repeated,
    );
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_SkeletonPainter old) =>
      old.t != t || old.a != a || old.b != b;
}

/// Text input styled like the artifact's `input` / `textarea`.
class AppField extends StatelessWidget {
  const AppField({
    super.key,
    this.controller,
    this.hint,
    this.onChanged,
    this.onSubmitted,
    this.obscure = false,
    this.keyboardType,
    this.maxLines = 1,
    this.minLines,
    this.readOnly = false,
    this.focusNode,
    this.textAlign = TextAlign.start,
    this.suffix,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  });

  final TextEditingController? controller;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool obscure;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? minLines;
  final bool readOnly;
  final FocusNode? focusNode;
  final TextAlign textAlign;
  final Widget? suffix;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final radius = BorderRadius.circular(14);
    final border = OutlineInputBorder(
        borderRadius: radius, borderSide: BorderSide(color: pal.ln));
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      obscureText: obscure,
      keyboardType: keyboardType ??
          (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
      maxLines: maxLines,
      minLines: minLines,
      readOnly: readOnly,
      textAlign: textAlign,
      cursorColor: pal.tx,
      style: TextStyle(
          fontSize: 14,
          color: pal.tx,
          height: 1.45,
          leadingDistribution: TextLeadingDistribution.even),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: pal.c,
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF757575), fontSize: 14),
        contentPadding: padding,
        suffixIcon: suffix,
        suffixIconConstraints: const BoxConstraints(),
        enabledBorder: border,
        focusedBorder: border,
        border: border,
      ),
    );
  }
}
