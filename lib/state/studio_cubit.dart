import 'dart:typed_data';
import 'package:flutter/painting.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/design_element.dart';
import '../models/design_model.dart';

/// The creator's "Upload design" form (`S.u`).
class StudioForm {
  const StudioForm({
    this.name = '',
    this.cat = 'Festivals',
    this.desc = '',
    this.headline = 'Your\nHeadline',
    this.subtitle = 'Your subtitle',
    this.emoji = '🎉',
    this.gradient = 0,
    this.mainImage,
    this.customBg,
    this.bgImage,
    this.premium = false,
    this.cost = 149,
  });

  final String name;
  final String cat;
  final String desc;
  final String headline;
  final String subtitle;
  final String emoji;

  /// Index into the catalogue's background presets; `-1` when editing a design whose
  /// colours are not one of the presets.
  final int gradient;
  final Uint8List? mainImage;
  final List<Color>? customBg;
  final Uint8List? bgImage;
  final bool premium;
  final int cost;

  StudioForm copyWith({
    String? name,
    String? cat,
    String? desc,
    String? headline,
    String? subtitle,
    String? emoji,
    int? gradient,
    Uint8List? mainImage,
    bool clearMainImage = false,
    Uint8List? bgImage,
    bool clearBgImage = false,
  }) {
    return StudioForm(
      name: name ?? this.name,
      cat: cat ?? this.cat,
      desc: desc ?? this.desc,
      headline: headline ?? this.headline,
      subtitle: subtitle ?? this.subtitle,
      emoji: emoji ?? this.emoji,
      gradient: gradient ?? this.gradient,
      mainImage: clearMainImage ? null : (mainImage ?? this.mainImage),
      customBg: customBg,
      bgImage: clearBgImage ? null : (bgImage ?? this.bgImage),
      premium: premium,
      cost: cost,
    );
  }

  /// Builds the preview / published design (`bt()` in the artifact).
  DesignModel toDesign(int id, List<List<Color>> presets) {
    const white = Color(0xFFFFFFFF);
    return DesignModel(
      id: id,
      name: name.isEmpty ? 'Untitled' : name,
      cat: cat,
      desc: desc,
      bg: gradient >= 0 && gradient < presets.length
          ? presets[gradient]
          : (customBg ?? const [Color(0xFF8A6A00), Color(0xFFEFBF05)]),
      bi: bgImage,
      by: 'You',
      pm: premium,
      cost: premium ? cost : 0,
      els: [
        if (bgImage != null)
          const DesignElement.shape(
              x: 0,
              y: 0,
              w: 100,
              h: 100,
              fill: Color.fromRGBO(0, 0, 0, .35)),
        DesignElement.text(
            x: 8,
            y: 9,
            w: 84,
            text: headline,
            size: 40,
            color: white,
            bold: true),
        DesignElement.image(
            x: 29, y: 37, w: 42, emoji: emoji, photo: true, image: mainImage),
        const DesignElement.shape(
            x: 12,
            y: 77,
            w: 76,
            h: 12,
            fill: Color.fromRGBO(0, 0, 0, .28),
            shape: ShapeStyle.pill),
        DesignElement.text(
            x: 12, y: 79.6, w: 76, text: subtitle, size: 18, color: white),
      ],
    );
  }

  /// Fills the form from an existing design (`eu(id)`).
  factory StudioForm.fromDesign(DesignModel d, List<List<Color>> presets) {
    final texts = d.els.where((e) => e.isText).toList();
    final image = d.els.firstWhere((e) => e.isImage);
    final g = presets.indexWhere((b) => b.first == d.bg.first);
    return StudioForm(
      name: d.name,
      cat: d.cat,
      desc: d.desc,
      headline: texts.first.text,
      subtitle: texts.last.text,
      emoji: image.emoji,
      mainImage: image.image,
      gradient: g,
      customBg: d.bg,
      bgImage: d.bi,
      premium: d.pm,
      cost: d.cost == 0 ? 149 : d.cost,
    );
  }
}

class StudioState {
  const StudioState({
    this.tab = 'Dashboard',
    this.form = const StudioForm(),
    this.editingId = 0,
    this.formVersion = 0,
  });

  /// Dashboard / My Designs / Upload.
  final String tab;
  final StudioForm form;

  /// Id of the template being edited, `0` for a new one (`S.ue`).
  final int editingId;

  /// Bumped whenever the form is replaced so text fields reload.
  final int formVersion;

  StudioState copyWith({
    String? tab,
    StudioForm? form,
    int? editingId,
    int? formVersion,
  }) =>
      StudioState(
        tab: tab ?? this.tab,
        form: form ?? this.form,
        editingId: editingId ?? this.editingId,
        formVersion: formVersion ?? this.formVersion,
      );
}

class StudioCubit extends Cubit<StudioState> {
  StudioCubit() : super(const StudioState());

  void setTab(String tab) => emit(state.copyWith(tab: tab));

  void update(StudioForm Function(StudioForm f) change) =>
      emit(state.copyWith(form: change(state.form)));

  /// `eu(id)`: edit an existing design.
  void edit(DesignModel d, List<List<Color>> presets) => emit(StudioState(
        tab: 'Upload',
        form: StudioForm.fromDesign(d, presets),
        editingId: d.id,
        formVersion: state.formVersion + 1,
      ));

  /// Clears the form and returns to the "My Designs" tab.
  void finish() => emit(StudioState(
        tab: 'My Designs',
        formVersion: state.formVersion + 1,
      ));

  void cancelEdit() => finish();

  void resetOnLogin() => emit(const StudioState());
}
