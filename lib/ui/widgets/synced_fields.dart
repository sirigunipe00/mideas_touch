import 'package:flutter/material.dart';
import 'kit.dart';

/// A text field that reports every keystroke and re-syncs when the model
/// value changes from outside (e.g. undo) without disturbing the caret.
class LiveTextField extends StatefulWidget {
  const LiveTextField({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint,
    this.maxLines = 1,
    this.minLines,
    this.keyboardType,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String? hint;
  final int maxLines;
  final int? minLines;
  final TextInputType? keyboardType;

  @override
  State<LiveTextField> createState() => _LiveTextFieldState();
}

class _LiveTextFieldState extends State<LiveTextField> {
  late final TextEditingController _c =
      TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(LiveTextField old) {
    super.didUpdateWidget(old);
    if (widget.value != _c.text) {
      final offset = _c.selection.baseOffset.clamp(0, widget.value.length);
      _c.value = TextEditingValue(
          text: widget.value, selection: TextSelection.collapsed(offset: offset));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppField(
        controller: _c,
        hint: widget.hint,
        onChanged: widget.onChanged,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        keyboardType: widget.keyboardType,
      );
}

/// A text field that commits on submit / blur (the HTML `onchange` event).
class CommitField extends StatefulWidget {
  const CommitField({
    super.key,
    required this.value,
    required this.onCommit,
    this.keyboardType,
    this.suffix,
    this.textAlign = TextAlign.start,
  });

  final String value;
  final ValueChanged<String> onCommit;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final TextAlign textAlign;

  @override
  State<CommitField> createState() => _CommitFieldState();
}

class _CommitFieldState extends State<CommitField> {
  late final TextEditingController _c =
      TextEditingController(text: widget.value);
  late final FocusNode _focus = FocusNode()..addListener(_onFocus);

  void _onFocus() {
    if (!_focus.hasFocus) _commit();
  }

  void _commit() {
    if (_c.text != widget.value) widget.onCommit(_c.text);
  }

  @override
  void didUpdateWidget(CommitField old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value && widget.value != _c.text) {
      _c.text = widget.value;
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppField(
        controller: _c,
        focusNode: _focus,
        keyboardType: widget.keyboardType,
        textAlign: widget.textAlign,
        suffix: widget.suffix,
        onSubmitted: (_) => _commit(),
      );
}
