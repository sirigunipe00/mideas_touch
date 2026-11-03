import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/canvas/design_renderer.dart';
import '../../core/canvas/image_store.dart';
import '../../models/design_model.dart';

/// Draws a design (the artifact's `.cv` square). Used for thumbnails,
/// previews and — with [selected] — the editor canvas.
class DesignCanvas extends StatefulWidget {
  const DesignCanvas({
    super.key,
    required this.design,
    this.selected = -1,
    this.guide = false,
    this.clip = true,
  });

  final DesignModel design;
  final int selected;
  final bool guide;

  /// The editor canvas lets handles overflow (`overflow: visible`).
  final bool clip;

  @override
  State<DesignCanvas> createState() => _DesignCanvasState();
}

class _DesignCanvasState extends State<DesignCanvas> {
  int _version = 0;

  @override
  void initState() {
    super.initState();
    _decodeImages();
  }

  @override
  void didUpdateWidget(DesignCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.design, widget.design)) _decodeImages();
  }

  void _decodeImages() {
    final d = widget.design;
    final all = <Uint8List>[
      if (d.bi != null) d.bi!,
      for (final e in d.els)
        if (e.image != null) e.image!,
    ];
    for (final bytes in all) {
      if (ImageStore.peek(bytes) == null) {
        ImageStore.load(bytes).then((_) {
          if (mounted) setState(() => _version++);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final paint = AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, c) => CustomPaint(
          size: Size.square(c.maxWidth),
          painter: _DesignPainter(
              widget.design, widget.selected, widget.guide, _version),
        ),
      ),
    );
    return widget.clip ? ClipRect(child: paint) : paint;
  }
}

class _DesignPainter extends CustomPainter {
  _DesignPainter(this.design, this.selected, this.guide, this.version);

  final DesignModel design;
  final int selected;
  final bool guide;
  final int version;

  @override
  void paint(Canvas canvas, Size size) {
    final n = size.width;
    paintDesign(canvas, n, design, ImageStore.peek);
    if (guide) paintGuide(canvas, n);
    if (selected >= 0 && selected < design.els.length) {
      paintSelection(canvas, n, design.els[selected]);
    }
  }

  @override
  bool shouldRepaint(_DesignPainter old) =>
      !identical(old.design, design) ||
      old.selected != selected ||
      old.guide != guide ||
      old.version != version;
}
