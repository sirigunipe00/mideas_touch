import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/painting.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/canvas/geometry.dart';
import '../models/design_element.dart';
import '../models/design_model.dart';

enum EditorTool { designs, text, images, elements, background }

/// An undo/redo snapshot (`snap()` in the artifact).
class EditorSnapshot {
  const EditorSnapshot(this.bg, this.bi, this.biPath, this.els);
  final List<Color> bg;
  final Uint8List? bi;
  final String? biPath;
  final List<DesignElement> els;
}

class EditorState {
  const EditorState({
    this.design,
    this.selected = -1,
    this.undoStack = const [],
    this.redoStack = const [],
    this.tool,
    this.assetQuery = '',
    this.removingBackground = false,
    this.guide = false,
    this.savedLabel = '',
    this.fileName = 'design',
    this.quality = .9,
    this.exportImage,
  });

  /// The design being edited / previewed (`S.cur`).
  final DesignModel? design;
  final int selected;
  final List<EditorSnapshot> undoStack;
  final List<EditorSnapshot> redoStack;
  final EditorTool? tool;
  final String assetQuery;
  final bool removingBackground;

  /// Red centre guide shown while dragging.
  final bool guide;
  final String savedLabel;
  final String fileName;
  final double quality;

  /// Last exported JPG (`S.img`).
  final Uint8List? exportImage;

  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;

  DesignElement? get selectedElement {
    final d = design;
    if (d == null || selected < 0 || selected >= d.els.length) return null;
    return d.els[selected];
  }

  EditorState copyWith({
    DesignModel? design,
    int? selected,
    List<EditorSnapshot>? undoStack,
    List<EditorSnapshot>? redoStack,
    Object? tool = _keep,
    String? assetQuery,
    bool? removingBackground,
    bool? guide,
    String? savedLabel,
    String? fileName,
    double? quality,
    Object? exportImage = _keep,
  }) {
    return EditorState(
      design: design ?? this.design,
      selected: selected ?? this.selected,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      tool: identical(tool, _keep) ? this.tool : tool as EditorTool?,
      assetQuery: assetQuery ?? this.assetQuery,
      removingBackground: removingBackground ?? this.removingBackground,
      guide: guide ?? this.guide,
      savedLabel: savedLabel ?? this.savedLabel,
      fileName: fileName ?? this.fileName,
      quality: quality ?? this.quality,
      exportImage: identical(exportImage, _keep)
          ? this.exportImage
          : exportImage as Uint8List?,
    );
  }
}

const Object _keep = Object();

class _Drag {
  _Drag(this.index, this.mode, this.original, this.before, this.start,
      this.n, this.center);
  final int index;
  final HitMode mode;
  final DesignElement original;
  final EditorSnapshot before;
  final Offset start;
  final double n;
  final Offset center;
  bool moved = false;
}

/// State and operations of the design editor: selection, undo / redo,
/// property edits, drag / resize / rotate gestures and export settings.
class EditorCubit extends Cubit<EditorState> {
  EditorCubit() : super(const EditorState());

  DateTime _burstUntil = DateTime.fromMillisecondsSinceEpoch(0);
  _Drag? _drag;
  Timer? _bgTimer;

  DesignModel get _d => state.design!;

  EditorSnapshot _snap() => EditorSnapshot(_d.bg, _d.bi, _d.biPath, _d.els);

  void _applySnap(EditorSnapshot s) => emit(state.copyWith(
      design: _d.copyWith(
          bg: s.bg,
          bi: s.bi,
          biPath: s.biPath,
          clearBi: s.bi == null,
          els: s.els),
      selected: -1));

  /// Records an undo point (`H()`).
  void _record() {
    emit(state.copyWith(
        undoStack: [...state.undoStack, _snap()], redoStack: const []));
  }

  /// Records an undo point only once per burst of rapid changes (sliders,
  /// typing), exactly like the artifact's debounce timers.
  void _recordBurst(Duration window) {
    final now = DateTime.now();
    if (now.isAfter(_burstUntil)) _record();
    _burstUntil = now.add(window);
  }

  /// Opens a design for editing and clears the history.
  void open(DesignModel design, {EditorTool? tool, String saved = ''}) {
    _bgTimer?.cancel();
    emit(state.copyWith(
      design: design,
      selected: -1,
      undoStack: const [],
      redoStack: const [],
      tool: tool,
      savedLabel: saved,
      removingBackground: false,
      guide: false,
    ));
  }

  /// Sets the design shown by preview / share without touching history.
  void setCurrent(DesignModel design) =>
      emit(state.copyWith(design: design, selected: -1));

  void replaceDesign(DesignModel design) =>
      emit(state.copyWith(design: design));

  void setTool(EditorTool tool) => emit(state.copyWith(
      tool: state.tool == tool ? null : tool, selected: -1));

  void deselect() => emit(state.copyWith(selected: -1));

  void select(int index) => emit(state.copyWith(selected: index));

  void setAssetQuery(String q) => emit(state.copyWith(assetQuery: q));

  void undo() {
    if (!state.canUndo) return;
    final u = [...state.undoStack];
    final snap = u.removeLast();
    final redo = [...state.redoStack, _snap()];
    emit(state.copyWith(undoStack: u, redoStack: redo));
    _applySnap(snap);
  }

  void redo() {
    if (!state.canRedo) return;
    final r = [...state.redoStack];
    final snap = r.removeLast();
    final undo = [...state.undoStack, _snap()];
    emit(state.copyWith(undoStack: undo, redoStack: r));
    _applySnap(snap);
  }

  /// Replaces the selected element (`sp(k, v)`), recording history.
  void updateSelected(DesignElement Function(DesignElement e) change) {
    final i = state.selected;
    if (i < 0) return;
    _record();
    _replace(i, change(_d.els[i]));
  }

  void _replace(int i, DesignElement e) {
    final els = [..._d.els];
    els[i] = e;
    emit(state.copyWith(design: _d.copyWith(els: els)));
  }

  /// Slider change (`sl(k, v)`): size and rotation.
  void slide({double? width, double? rotation}) {
    final i = state.selected;
    if (i < 0) return;
    _recordBurst(const Duration(milliseconds: 600));
    var e = _d.els[i];
    if (width != null) {
      final ratio = width / e.w;
      e = e.copyWith(
        w: width,
        h: e.isShape ? e.h * ratio : null,
        size: e.isText ? e.size * ratio : null,
      );
    }
    if (rotation != null) e = e.copyWith(r: rotation);
    _replace(i, e);
  }

  /// Typing in the text field (`tx(v)`).
  void typeText(String value) {
    final i = state.selected;
    if (i < 0) return;
    _recordBurst(const Duration(milliseconds: 800));
    _replace(i, _d.els[i].copyWith(text: value));
  }

  void changeFontSize(double delta) {
    final e = state.selectedElement;
    if (e == null) return;
    updateSelected((e) => e.copyWith(
        size: math.max(8, (e.size + delta).roundToDouble())));
  }

  void deleteSelected() {
    final i = state.selected;
    if (i < 0) return;
    _record();
    final els = [..._d.els]..removeAt(i);
    emit(state.copyWith(design: _d.copyWith(els: els), selected: -1));
  }

  void addElement(DesignElement e) {
    _record();
    final els = [..._d.els, e];
    emit(state.copyWith(
        design: _d.copyWith(els: els), selected: els.length - 1));
  }

  /// `addImg(i)`: swap the emoji of the selected image or add a new one.
  void addStockImage(String emoji) {
    final e = state.selectedElement;
    if (e != null && e.isImage) {
      updateSelected((e) => e.copyWith(emoji: emoji, clearImage: true));
    } else {
      addElement(
          DesignElement.image(x: 35, y: 35, w: 30, emoji: emoji, photo: true));
    }
  }

  void setBackground(List<Color> colors) {
    _record();
    emit(state.copyWith(
        design: _d.copyWith(bg: colors, clearBi: true)));
  }

  /// `swap(id)`: apply another template's look to the current design.
  void swapTemplate(DesignModel template) {
    _record();
    emit(state.copyWith(
      design: _d.copyWith(
          bg: template.bg,
          bi: template.bi,
          biPath: template.biPath,
          sourceId: template.id,
          clearBi: template.bi == null,
          els: template.els),
      selected: -1,
    ));
  }

  /// "Remove Background": a simulated 1.6s operation on the selected image.
  /// Completes when the background has been removed.
  Future<bool> removeBackground() async {
    final i = state.selected;
    final e = state.selectedElement;
    if (e == null || !e.photo) return false;
    _record();
    emit(state.copyWith(removingBackground: true));
    final c = Completer<bool>();
    _bgTimer?.cancel();
    _bgTimer = Timer(const Duration(milliseconds: 1600), () {
      if (isClosed) {
        c.complete(false);
        return;
      }
      if (state.design != null && i < _d.els.length) {
        _replace(i, _d.els[i].copyWith(photo: false));
      }
      emit(state.copyWith(removingBackground: false));
      c.complete(true);
    });
    return c.future;
  }

  void markSaved(DesignModel saved, String label) =>
      emit(state.copyWith(design: saved, savedLabel: label));

  void markCompleted() =>
      emit(state.copyWith(design: _d.copyWith(status: 'Completed')));

  // ---- export settings -------------------------------------------------

  void setFileName(String v) => emit(state.copyWith(fileName: v));

  void setQuality(double v) => emit(state.copyWith(quality: v));

  void setExportImage(Uint8List? bytes) =>
      emit(state.copyWith(exportImage: bytes));

  // ---- canvas gestures -------------------------------------------------

  /// Pointer pressed on the canvas. [inside] tells whether the point lies on
  /// the canvas itself (handles may extend outside it).
  void pointerDown(Offset p, Offset global, double n, {required bool inside}) {
    final d = state.design;
    if (d == null) return;
    final hit = ElementGeometry.hitTest(d.els, n, state.selected, p);
    if (hit == null) {
      if (inside) deselect();
      return;
    }
    final e = d.els[hit.index];
    final box = ElementGeometry.boxOf(e, n);
    // Drag deltas use global coordinates so they stay stable even when the
    // stage resizes because the property panel appears.
    _drag = _Drag(hit.index, hit.mode, e, _snap(), global, n,
        global - p + box.center);
    if (state.selected != hit.index) select(hit.index);
  }

  void pointerMove(Offset global) {
    final p = global;
    final drag = _drag;
    if (drag == null || state.design == null) return;
    drag.moved = true;
    final o = drag.original;
    final dx = (p.dx - drag.start.dx) / drag.n * 100;
    final dy = (p.dy - drag.start.dy) / drag.n * 100;
    var guide = false;
    DesignElement e;
    switch (drag.mode) {
      case HitMode.move:
        var nx = o.x + dx;
        if ((nx + o.w / 2 - 50).abs() < 1.5) {
          nx = 50 - o.w / 2;
          guide = true;
        }
        e = o.copyWith(x: nx, y: o.y + dy);
        break;
      case HitMode.resize:
        final w = math.max(6.0, o.w + dx);
        final q = w / o.w;
        e = o.copyWith(
          w: w,
          h: o.isShape ? o.h * q : null,
          size: o.isText ? o.size * q : null,
        );
        break;
      case HitMode.rotate:
        final a = math.atan2(p.dy - drag.center.dy, p.dx - drag.center.dx);
        e = o.copyWith(r: (a * 180 / math.pi + 90).roundToDouble());
        break;
    }
    final els = [..._d.els];
    els[drag.index] = e;
    emit(state.copyWith(design: _d.copyWith(els: els), guide: guide));
  }

  void pointerUp() {
    final drag = _drag;
    _drag = null;
    if (drag == null) return;
    if (drag.moved) {
      emit(state.copyWith(
          undoStack: [...state.undoStack, drag.before],
          redoStack: const [],
          guide: false));
    } else if (state.guide) {
      emit(state.copyWith(guide: false));
    }
  }

  @override
  Future<void> close() {
    _bgTimer?.cancel();
    return super.close();
  }
}
