import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/fonts/google_fonts_service.dart';
import '../../core/theme/palette.dart';

/// Opens a searchable list of fonts. The app's own fonts come first, then the
/// full Google Fonts catalogue. Every name is previewed in its own typeface.
Future<void> showFontPicker(
  BuildContext context, {
  required String current,
  required List<String> catalogFonts,
  required ValueChanged<String> onPick,
}) {
  final pal = context.pal;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: pal.c,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => _FontPickerSheet(
      current: current,
      catalogFonts: catalogFonts,
      onPick: (family) {
        Navigator.of(sheetContext).pop();
        onPick(family);
      },
    ),
  );
}

class _FontPickerSheet extends StatefulWidget {
  const _FontPickerSheet({
    required this.current,
    required this.catalogFonts,
    required this.onPick,
  });

  final String current;
  final List<String> catalogFonts;
  final ValueChanged<String> onPick;

  @override
  State<_FontPickerSheet> createState() => _FontPickerSheetState();
}

class _Row {
  const _Row(this.label, {this.header = false});
  final String label;
  final bool header;
}

class _FontPickerSheetState extends State<_FontPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final q = _query.trim().toLowerCase();
    bool matches(String f) => q.isEmpty || f.toLowerCase().contains(q);

    final own = <String>{
      ...GoogleFontsService.bundled,
      ...widget.catalogFonts,
    }.where(matches).toList();
    final ownSet = own.toSet();
    final google = [
      for (final f in GoogleFontsService.families)
        if (!ownSet.contains(f) && matches(f)) f,
    ];

    final rows = <_Row>[
      if (own.isNotEmpty) const _Row('Your fonts', header: true),
      for (final f in own) _Row(f),
      if (google.isNotEmpty)
        _Row('All Google Fonts (${google.length})', header: true),
      for (final f in google) _Row(f),
    ];

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .8,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: TextField(
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'Search fonts',
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: GoogleFontsService.revision,
              builder: (context, _, __) => ListView.builder(
                itemCount: rows.length,
                itemBuilder: (context, i) {
                  final row = rows[i];
                  if (row.header) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(row.label,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: pal.mu)),
                    );
                  }
                  final family = row.label;
                  // Fetch the preview face when the row scrolls into view.
                  unawaited(GoogleFontsService.ensure(family));
                  final selected = family == widget.current;
                  return ListTile(
                    dense: true,
                    title: Text(
                      family,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: GoogleFontsService.resolve(family),
                        fontSize: 18,
                        color: pal.tx,
                      ),
                    ),
                    trailing: selected
                        ? Icon(Icons.check, color: pal.tx, size: 20)
                        : null,
                    onTap: () => widget.onPick(family),
                  );
                },
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
