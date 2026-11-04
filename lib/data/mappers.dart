import 'package:flutter/painting.dart';
import '../models/catalog_models.dart';
import '../models/design_element.dart';
import '../models/design_model.dart';

/// Row ⇄ model conversions for the Supabase tables. Pure functions, so they
/// can be tested without a backend.

double _n(Object? v, [double fallback = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

int _i(Object? v) => v is num ? v.toInt() : int.parse('$v');

String colorHex(Color c) =>
    '#${(c.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// A `templates` row (with embedded `categories(name)` and
/// `template_elements(*)`) as a [DesignModel].
DesignModel templateFromRow(Map<String, dynamic> r) {
  final category = r['categories'];
  final elementRows = [
    for (final e in (r['template_elements'] as List? ?? const []))
      Map<String, dynamic>.from(e as Map)
  ]..sort((a, b) => _i(a['z_index']).compareTo(_i(b['z_index'])));
  return DesignModel(
    id: _i(r['id']),
    name: r['name'] as String,
    cat: category is Map ? (category['name'] as String? ?? 'Other') : 'Other',
    desc: (r['description'] as String?) ?? '',
    bg: [hex(r['bg_from'] as String), hex(r['bg_to'] as String)],
    biPath: r['background_image_path'] as String?,
    by: (r['author_name'] as String?) ?? 'Studio Team',
    pm: r['is_premium'] == true,
    cost: _i(r['price_inr'] ?? 0),
    els: [for (final e in elementRows) elementFromRow(e)],
  );
}

DesignElement elementFromRow(Map<String, dynamic> r) {
  final x = _n(r['x']), y = _n(r['y']), w = _n(r['w']);
  final rotation = _n(r['rotation']);
  switch (r['kind']) {
    case 'shape':
      return DesignElement(
        kind: ElementKind.shape,
        x: x,
        y: y,
        w: w,
        h: _n(r['h']),
        r: rotation,
        fill: hex((r['fill'] as String?) ?? '#fde68a'),
        shape: ShapeStyle.values.asNameMap()[r['shape_style']] ??
            ShapeStyle.rect,
      );
    case 'image':
      return DesignElement(
        kind: ElementKind.image,
        x: x,
        y: y,
        w: w,
        r: rotation,
        emoji: (r['emoji'] as String?) ?? '',
        photo: r['is_photo'] == true,
      );
    default:
      return DesignElement(
        kind: ElementKind.text,
        x: x,
        y: y,
        w: w,
        r: rotation,
        text: (r['text_content'] as String?) ?? '',
        font: (r['font_family'] as String?) ?? 'Poppins',
        size: _n(r['font_size'], 20),
        color: hex((r['color'] as String?) ?? '#ffffff'),
        bold: r['bold'] == true,
        italic: r['italic'] == true,
        underline: r['underline'] == true,
        align: TextAlign.values.asNameMap()[r['text_align']] ??
            TextAlign.center,
      );
  }
}

/// A `user_designs` row as a saved [DesignModel] ("My Designs").
DesignModel userDesignFromRow(Map<String, dynamic> r, {DateTime? now}) {
  final updated = DateTime.tryParse('${r['updated_at']}')?.toLocal();
  return DesignModel(
    id: _i(r['id']),
    name: r['name'] as String,
    cat: (r['category'] as String?) ?? '',
    desc: (r['description'] as String?) ?? '',
    bg: [hex(r['bg_from'] as String), hex(r['bg_to'] as String)],
    biPath: r['background_image_path'] as String?,
    sourceId: r['source_template_id'] == null ? null : _i(r['source_template_id']),
    status: (r['status'] as String?) ?? 'Draft',
    mod: updated == null ? '' : formatModified(updated, now ?? DateTime.now()),
    els: [
      for (final e in (r['elements'] as List? ?? const []))
        DesignElement.fromJson(Map<String, dynamic>.from(e as Map))
    ],
  );
}

/// The `user_designs` row for [d]. `updated_at` is set by the database.
Map<String, Object?> userDesignToRow(DesignModel d, String userId) => {
      'user_id': userId,
      'id': d.id,
      'source_template_id': d.sourceId,
      'name': d.name,
      'category': d.cat,
      'description': d.desc,
      'bg_from': colorHex(d.bg.first),
      'bg_to': colorHex(d.bg.last),
      'background_image_path': d.biPath,
      'elements': [for (final e in d.els) e.toJson()],
      'status': d.status == 'Completed' ? 'Completed' : 'Draft',
    };

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

/// "Just now", "Today, 10:42 AM", "Yesterday, 6:15 PM", "Oct 28, 4:05 PM".
String formatModified(DateTime t, DateTime now) {
  if (now.difference(t).inMinutes.abs() < 1) return 'Just now';
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final clock =
      '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
  final day = DateTime(t.year, t.month, t.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today, $clock';
  if (diff == 1) return 'Yesterday, $clock';
  return '${_months[t.month - 1]} ${t.day}, $clock';
}
