import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'design_element.dart';

/// A design / template (the artifact's template object `T[i]`).
@immutable
class DesignModel {
  const DesignModel({
    required this.id,
    required this.name,
    required this.cat,
    this.desc = '',
    required this.bg,
    this.bi,
    this.biPath,
    this.sourceId,
    this.by = 'Studio Team',
    this.pm = false,
    this.cost = 0,
    this.status = '',
    this.mod = '',
    required this.els,
  });

  final int id;
  final String name;
  final String cat;
  final String desc;

  /// The two gradient colours.
  final List<Color> bg;

  /// Uploaded background picture (overrides the gradient when present).
  final Uint8List? bi;

  /// Where [bi] lives in Storage (bucket `app-assets`), when it came from there.
  final String? biPath;

  /// The template a saved design was made from (`user_designs.source_template_id`).
  final int? sourceId;
  final String by;
  final bool pm;
  final int cost;

  /// `Draft`, `Completed` or `Published` for user designs.
  final String status;

  /// "Last edited" text.
  final String mod;
  final List<DesignElement> els;

  DesignModel copyWith({
    int? id,
    String? name,
    String? cat,
    String? desc,
    List<Color>? bg,
    Uint8List? bi,
    String? biPath,
    int? sourceId,
    bool clearBi = false,
    String? by,
    bool? pm,
    int? cost,
    String? status,
    String? mod,
    List<DesignElement>? els,
  }) {
    return DesignModel(
      id: id ?? this.id,
      name: name ?? this.name,
      cat: cat ?? this.cat,
      desc: desc ?? this.desc,
      bg: bg ?? this.bg,
      bi: clearBi ? null : (bi ?? this.bi),
      biPath: clearBi ? null : (biPath ?? this.biPath),
      sourceId: sourceId ?? this.sourceId,
      by: by ?? this.by,
      pm: pm ?? this.pm,
      cost: cost ?? this.cost,
      status: status ?? this.status,
      mod: mod ?? this.mod,
      els: els ?? this.els,
    );
  }
}
