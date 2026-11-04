import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../app/app_controller.dart';
import '../../core/theme/css_gradient.dart';
import '../../core/theme/palette.dart';
import '../../models/design_element.dart';
import '../../state/catalog_cubit.dart';
import '../../state/editor_cubit.dart';
import '../../state/nav_cubit.dart';
import '../widgets/color_picker.dart';
import '../widgets/common.dart';
import '../widgets/design_canvas.dart';
import '../widgets/kit.dart';
import '../widgets/stage.dart';
import '../widgets/synced_fields.dart';

/// `ED()`: the design editor.
class EditorScreen extends StatelessWidget {
  const EditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EditorCubit, EditorState>(builder: (context, st) {
      if (st.design == null) return const SizedBox();
      return LayoutBuilder(
        builder: (context, c) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _EditorHeader(st),
          Expanded(child: _EditorStage(st)),
          if (st.selected >= 0)
            _PropertyPanel(st, maxHeight: c.maxHeight * .4)
          else if (st.tool != null)
            _ToolPanel(st),
          _ToolBar(st),
        ]),
      );
    });
  }
}

class _EditorHeader extends StatelessWidget {
  const _EditorHeader(this.st);

  final EditorState st;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final cubit = context.read<EditorCubit>();
    return ScreenHeader(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      gap: 6,
      children: [
        IconBox(
            label: 'Back',
            onTap: context.read<NavCubit>().back,
            child: const Text('←')),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(st.design!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: kSemi)),
                Text(st.savedLabel.isEmpty ? 'Unsaved' : st.savedLabel,
                    style: TextStyle(fontSize: 11.67, color: pal.mu)),
              ]),
        ),
        IconBox(
            label: 'Undo',
            dim: !st.canUndo,
            onTap: cubit.undo,
            child: const Text('↶')),
        IconBox(
            label: 'Redo',
            dim: !st.canRedo,
            onTap: cubit.redo,
            child: const Text('↷')),
        IconBox(
            label: 'Preview',
            onTap: () => context.read<NavCubit>().go(AppView.preview),
            child: const Text('👁')),
        AppButton('Save', small: true, onTap: context.app.save),
        AppButton('⬆', small: true, onTap: context.app.openExport),
      ],
    );
  }
}

class _EditorStage extends StatefulWidget {
  const _EditorStage(this.st);

  final EditorState st;

  @override
  State<_EditorStage> createState() => _EditorStageState();
}

class _EditorStageState extends State<_EditorStage> {
  double _side = 1;
  Offset _origin = Offset.zero;
  int? _pointer;

  @override
  Widget build(BuildContext context) {
    final st = widget.st;
    final cubit = context.read<EditorCubit>();
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        if (_pointer != null) return;
        _pointer = e.pointer;
        final local = e.localPosition - _origin;
        final inside = local.dx >= 0 &&
            local.dy >= 0 &&
            local.dx <= _side &&
            local.dy <= _side;
        cubit.pointerDown(local, e.position, _side, inside: inside);
      },
      onPointerMove: (e) {
        if (e.pointer == _pointer) cubit.pointerMove(e.position);
      },
      onPointerUp: (e) {
        if (e.pointer == _pointer) {
          _pointer = null;
          cubit.pointerUp();
        }
      },
      onPointerCancel: (e) {
        if (e.pointer == _pointer) {
          _pointer = null;
          cubit.pointerUp();
        }
      },
      child: Stage(
        onLayout: (side, origin) {
          _side = side;
          _origin = origin;
        },
        builder: (context, side) => Stack(clipBehavior: Clip.none, children: [
          DesignCanvas(
              design: st.design!,
              selected: st.selected,
              guide: st.guide,
              clip: false),
          if (st.removingBackground)
            Positioned.fill(
              child: Container(
                alignment: Alignment.center,
                color: const Color.fromRGBO(20, 15, 0, .65),
                child: const Text('Removing background...',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontWeight: kSemi)),
              ),
            ),
        ]),
      ),
    );
  }
}

class _ToolBar extends StatelessWidget {
  const _ToolBar(this.st);

  final EditorState st;

  static const _tools = [
    (EditorTool.designs, '▦', 'Designs'),
    (EditorTool.text, 'T', 'Text'),
    (EditorTool.images, '🌄', 'Images'),
    (EditorTool.elements, '◆', 'Elements'),
    (EditorTool.background, '🎨', 'Background'),
  ];

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      decoration: BoxDecoration(
          color: pal.c, border: Border(top: BorderSide(color: pal.ln))),
      child: Row(children: [
        for (final t in _tools)
          Expanded(
            child: Tap(
              onTap: () => context.read<EditorCubit>().setTool(t.$1),
              label: t.$3,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  color: st.tool == t.$1 && st.selected < 0 ? pal.pl2 : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(t.$2,
                      style: TextStyle(
                          fontSize: 19,
                          color: st.tool == t.$1 && st.selected < 0
                              ? pal.tx
                              : pal.mu)),
                  Text(t.$3,
                      style: TextStyle(
                          fontSize: 10,
                          color: st.tool == t.$1 && st.selected < 0
                              ? pal.tx
                              : pal.mu)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

class _ToolPanel extends StatelessWidget {
  const _ToolPanel(this.st);

  final EditorState st;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final cubit = context.read<EditorCubit>();
    final stock = context.watch<CatalogCubit>().state.assets;
    Widget body;
    switch (st.tool!) {
      case EditorTool.text:
        body = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            AppButton('+ Heading',
                style: BtnStyle.ghost,
                onTap: () => cubit.addElement(NewElements.heading)),
            const SizedBox(width: 8),
            AppButton('+ Subtitle',
                style: BtnStyle.ghost,
                onTap: () => cubit.addElement(NewElements.subtitle)),
          ]),
        );
      case EditorTool.designs:
        final templates = context.watch<CatalogCubit>().state.templates;
        body = CardRow(children: [
          for (final d in templates)
            Tap(
                onTap: () => context.app.swapTemplate(d),
                child: DesignCard(d, width: 84, compact: true)),
        ]);
      case EditorTool.images:
        final q = st.assetQuery.toLowerCase();
        final matches = matchingAssetIndexes(stock, q);
        body = Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: LiveTextField(
                value: st.assetQuery,
                hint: 'Search images...',
                onChanged: cubit.setAssetQuery),
          ),
          if (matches.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                  alignment: Alignment.centerLeft,
                  child:
                      Text('No images found', style: TextStyle(color: pal.mu))),
            )
          else
            ArtifactGrid(columns: 4, children: [
              for (final i in matches)
                AssetCell(stock[i].emoji,
                    fontSize: 24,
                    onTap: () => cubit.addStockImage(stock[i].emoji)),
            ]),
        ]);
      case EditorTool.elements:
        body = ArtifactGrid(columns: 4, children: [
          AssetCell('●',
              fontSize: 24, onTap: () => cubit.addElement(NewElements.circle)),
          AssetCell('■',
              fontSize: 24, onTap: () => cubit.addElement(NewElements.square)),
          AssetCell('▬',
              fontSize: 24, onTap: () => cubit.addElement(NewElements.bar)),
        ]);
      case EditorTool.background:
        body = ArtifactGrid(columns: 6, children: [
          for (final b in context.watch<CatalogCubit>().state.backgrounds)
            Tap(
              onTap: () => cubit.setBackground(b),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  gradient: CssLinearGradient(145, b),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: pal.ln),
                ),
              ),
            ),
        ]);
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
          color: pal.c, border: Border(top: BorderSide(color: pal.ln))),
      child: body,
    );
  }
}

class _PropertyPanel extends StatelessWidget {
  const _PropertyPanel(this.st, {required this.maxHeight});

  final EditorState st;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final cubit = context.read<EditorCubit>();
    final e = st.selectedElement;
    if (e == null) return const SizedBox();
    final title = switch (e.kind) {
      ElementKind.text => 'Text',
      ElementKind.shape => 'Shape',
      ElementKind.image => 'Image',
    };
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: pal.c,
        border: Border(top: BorderSide(color: pal.ln)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(title, style: const TextStyle(fontWeight: kSemi)),
            Row(children: [
              IconBox(
                  label: 'Delete',
                  onTap: cubit.deleteSelected,
                  child: const Text('🗑')),
              const SizedBox(width: 8),
              IconBox(
                  label: 'Done', onTap: cubit.deselect, child: const Text('✓')),
            ]),
          ]),
          if (e.isText) ..._textControls(context, cubit, e),
          if (e.isShape) ...[
            const FieldLabel('Colour'),
            ColorInput(
              color: e.fill.alpha == 255 ? e.fill : const Color(0xFFFFFFFF),
              onChanged: (c) => cubit.updateSelected((x) => x.copyWith(fill: c)),
            ),
          ],
          if (e.isImage) ...[
            const SizedBox(height: 10),
            AppButton(
              e.photo ? '✂ Remove Background' : '✓ Background removed',
              style: BtnStyle.ghost,
              wide: true,
              onTap: e.photo ? context.app.removeBackground : null,
            ),
            const FieldLabel('Change image'),
            ArtifactGrid(
              columns: 6,
              padding: EdgeInsets.zero,
              children: [
                for (final a in context
                    .read<CatalogCubit>()
                    .state
                    .assets
                    .take(6))
                  AssetCell(a.emoji,
                      fontSize: 20, onTap: () => cubit.addStockImage(a.emoji)),
              ],
            ),
          ],
          if (!e.isText) ...[
            const FieldLabel('Size'),
            ThemedSlider(
                value: e.w,
                min: 8,
                max: 90,
                onChanged: (v) => cubit.slide(width: v)),
          ],
          const FieldLabel('Rotate'),
          ThemedSlider(
              value: e.r,
              min: -180,
              max: 180,
              onChanged: (v) => cubit.slide(rotation: v.roundToDouble())),
        ]),
      ),
    );
  }

  List<Widget> _textControls(
      BuildContext context, EditorCubit cubit, DesignElement e) {
    final pal = context.pal;
    Widget toggle(Widget label, bool on, VoidCallback onTap) =>
        IconBox(on: on, onTap: onTap, child: label);
    return [
      const FieldLabel('Text'),
      LiveTextField(
        value: e.text.replaceAll('\n', ' / '),
        onChanged: (v) => cubit.typeText(v.replaceAll(' / ', '\n')),
      ),
      const FieldLabel('Font'),
      CommitField(
        value: e.font,
        onCommit: (v) => cubit.updateSelected((x) => x.copyWith(font: v)),
        suffix: PopupMenuButton<String>(
          tooltip: 'Fonts',
          padding: EdgeInsets.zero,
          color: pal.c,
          icon: Text('▾', style: TextStyle(color: pal.mu)),
          onSelected: (v) => cubit.updateSelected((x) => x.copyWith(font: v)),
          itemBuilder: (_) => [
            for (final f in context.read<CatalogCubit>().state.fonts)
              PopupMenuItem(
                  value: f,
                  child: Text(f,
                      style: TextStyle(fontFamily: f, color: pal.tx))),
          ],
        ),
      ),
      const FieldLabel('Size'),
      Row(children: [
        IconBox(
            label: 'Smaller',
            onTap: () => cubit.changeFontSize(-2),
            child: const Text('−')),
        const SizedBox(width: 8),
        SizedBox(
          width: 76,
          child: CommitField(
            value: e.size.round().toString(),
            keyboardType: TextInputType.number,
            onCommit: (v) {
              final n = double.tryParse(v.trim());
              if (n != null && n > 0) {
                cubit.updateSelected((x) => x.copyWith(size: n));
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        IconBox(
            label: 'Larger',
            onTap: () => cubit.changeFontSize(2),
            child: const Text('+')),
        const SizedBox(width: 8),
        ColorInput(
          width: 46,
          color: e.color,
          onChanged: (c) => cubit.updateSelected((x) => x.copyWith(color: c)),
        ),
      ]),
      const FieldLabel('Style and alignment'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        toggle(const Text('B', style: TextStyle(fontWeight: kSemi)), e.bold,
            () => cubit.updateSelected((x) => x.copyWith(bold: !x.bold))),
        toggle(const Text('I', style: TextStyle(fontStyle: FontStyle.italic)),
            e.italic,
            () => cubit.updateSelected((x) => x.copyWith(italic: !x.italic))),
        toggle(
            const Text('U',
                style: TextStyle(decoration: TextDecoration.underline)),
            e.underline,
            () => cubit
                .updateSelected((x) => x.copyWith(underline: !x.underline))),
        for (final a in const [
          (TextAlign.left, 'Left'),
          (TextAlign.center, 'Center'),
          (TextAlign.right, 'Right'),
        ])
          toggle(Text(a.$2), e.align == a.$1,
              () => cubit.updateSelected((x) => x.copyWith(align: a.$1))),
      ]),
    ];
  }
}
