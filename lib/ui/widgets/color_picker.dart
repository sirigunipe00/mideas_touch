import 'package:flutter/material.dart';
import '../../core/theme/palette.dart';
import 'kit.dart';

/// Colour swatch that opens a picker (stands in for `<input type=color>`).
class ColorInput extends StatelessWidget {
  const ColorInput({super.key, required this.color, required this.onChanged, this.width});

  final Color color;
  final ValueChanged<Color> onChanged;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Tap(
      label: 'Pick colour',
      onTap: () async {
        final picked = await showDialog<Color>(
            context: context,
            builder: (_) => _ColorPickerDialog(initial: color));
        if (picked != null) onChanged(picked);
      },
      child: Container(
        width: width,
        height: 34,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: pal.c,
          border: Border.all(color: pal.ln),
          borderRadius: BorderRadius.circular(14),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
              color: color.withOpacity(1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black.withOpacity(.2))),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

const _palette = [
  '#ffffff', '#000000', '#1d1700', '#efbf05', '#f6da6f', '#fde68a',
  '#ed0707', '#f97316', '#facc15', '#15803d', '#06b6d4', '#1e3a8a',
  '#6d28d9', '#ec4899', '#7c2d12', '#fcf4d3', '#9ca3af', '#111827',
];

Color _fromHex(String h) =>
    Color(int.parse('FF${h.replaceAll('#', '')}', radix: 16));

String _toHex(Color c) =>
    '#${(c.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.initial});

  final Color initial;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial.withOpacity(1));
  late final TextEditingController _hex =
      TextEditingController(text: _toHex(_hsv.toColor()));

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _set(HSVColor v) {
    setState(() => _hsv = v);
    _hex.text = _toHex(v.toColor());
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final color = _hsv.toColor();
    return Dialog(
      backgroundColor: pal.c,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: SingleChildScrollView(
          child: DefaultTextStyle.merge(
            style: TextStyle(color: pal.tx),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pick a colour',
                    style: TextStyle(fontSize: 16, fontWeight: kBold)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final h in _palette)
                    Tap(
                      onTap: () => _set(HSVColor.fromColor(_fromHex(h))),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: _fromHex(h),
                          shape: BoxShape.circle,
                          border: Border.all(color: pal.ln, width: 1.5),
                        ),
                      ),
                    ),
                ]),
                const SizedBox(height: 8),
                _slider('Hue', _hsv.hue, 360,
                    (v) => _set(_hsv.withHue(v))),
                _slider('Saturation', _hsv.saturation, 1,
                    (v) => _set(_hsv.withSaturation(v))),
                _slider('Brightness', _hsv.value, 1,
                    (v) => _set(_hsv.withValue(v))),
                const SizedBox(height: 8),
                Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: pal.ln)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppField(
                      controller: _hex,
                      onChanged: (v) {
                        final m = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(v.trim());
                        if (m != null) {
                          setState(() => _hsv =
                              HSVColor.fromColor(_fromHex(m.group(1)!)));
                        }
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                      child: AppButton('Cancel',
                          style: BtnStyle.ghost,
                          wide: true,
                          onTap: () => Navigator.pop(context))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: AppButton('Done',
                          wide: true,
                          onTap: () => Navigator.pop(context, color))),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _slider(
      String label, double value, double max, ValueChanged<double> onChanged) {
    return Row(children: [
      SizedBox(
          width: 82,
          child: Text(label,
              style: TextStyle(fontSize: 11, color: context.pal.mu))),
      Expanded(
          child: ThemedSlider(
              value: value.clamp(0, max).toDouble(),
              min: 0,
              max: max,
              onChanged: onChanged)),
    ]);
  }
}

/// A slider with the app's gold accent (`input[type=range]`, 34px high).
class ThemedSlider extends StatelessWidget {
  const ThemedSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.onChangeEnd,
    this.divisions,
  });

  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final int? divisions;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return SizedBox(
      height: 34,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor: pal.p,
          inactiveTrackColor: pal.ln,
          thumbColor: pal.p,
          overlayColor: pal.p.withOpacity(.15),
          trackHeight: 4,
        ),
        child: Slider(
          value: value.clamp(min, max).toDouble(),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ),
    );
  }
}
