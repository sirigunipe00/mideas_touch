import 'dart:typed_data';
import 'package:flutter/painting.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/repositories.dart';
import '../models/catalog_models.dart';
import '../models/design_model.dart';

enum CatalogStatus { loading, ready, error }

class CatalogState {
  const CatalogState({
    this.data = const CatalogData(),
    this.status = CatalogStatus.loading,
    this.error = '',
    this.query = '',
  });

  /// Everything loaded from the backend (empty until [status] is `ready`).
  final CatalogData data;
  final CatalogStatus status;
  final String error;

  /// Search text (`S.q`).
  final String query;

  bool get loading => status == CatalogStatus.loading;

  /// All templates (`T`).
  List<DesignModel> get templates => data.templates;
  List<String> get categories => data.categories;
  List<String> get fonts => data.fonts;
  List<StockAsset> get assets => data.assets;
  List<List<Color>> get backgrounds => data.backgrounds;

  DesignModel? byId(int id) {
    for (final d in templates) {
      if (d.id == id) return d;
    }
    return null;
  }

  /// Templates created by the signed-in creator (`my()`).
  List<DesignModel> get mine => templates.where((d) => d.by == 'You').toList();

  CatalogState copyWith({
    CatalogData? data,
    CatalogStatus? status,
    String? error,
    String? query,
  }) =>
      CatalogState(
        data: data ?? this.data,
        status: status ?? this.status,
        error: error ?? this.error,
        query: query ?? this.query,
      );
}

/// The catalogue loaded from Supabase (categories, templates, coin packs …)
/// and the search query. Nothing is cached on disk; template pictures are
/// downloaded into memory after the rows arrive.
class CatalogCubit extends Cubit<CatalogState> {
  CatalogCubit(this._repo) : super(const CatalogState());

  final CatalogRepository _repo;

  /// Loads (or reloads) the catalogue.
  Future<void> load() async {
    emit(state.copyWith(status: CatalogStatus.loading, error: ''));
    try {
      final data = await _repo.load();
      if (isClosed) return;
      emit(state.copyWith(data: data, status: CatalogStatus.ready));
      await loadPictures();
    } on AppException catch (e) {
      if (isClosed) return;
      emit(state.copyWith(status: CatalogStatus.error, error: e.message));
    }
  }

  /// A picture from Storage (cached in memory by the repository).
  Future<Uint8List?> image(String path) => _repo.image(path);

  /// Downloads the template pictures four at a time; each card switches from
  /// its placeholder gradient to the picture as soon as it arrives.
  Future<void> loadPictures() async {
    final pending = [
      for (final t in state.templates)
        if (t.biPath != null && t.bi == null) t
    ];
    var next = 0;
    Future<void> worker() async {
      while (next < pending.length && !isClosed) {
        final t = pending[next++];
        final bytes = await _repo.image(t.biPath!);
        if (bytes != null && !isClosed) _attach(t.id, bytes);
      }
    }

    await Future.wait([for (var i = 0; i < 4; i++) worker()]);
  }

  void _attach(int id, Uint8List bytes) {
    final list = [
      for (final d in state.templates) d.id == id ? d.copyWith(bi: bytes) : d
    ];
    emit(state.copyWith(data: state.data.copyWith(templates: list)));
  }

  void setQuery(String q) => emit(state.copyWith(query: q));

  // Creator publishing is on hold: these only change the in-memory list.
  void publish(DesignModel d, {required bool replace}) {
    final list = [...state.templates];
    if (replace) {
      final i = list.indexWhere((x) => x.id == d.id);
      if (i >= 0) {
        list[i] = d;
      } else {
        list.add(d);
      }
    } else {
      list.add(d);
    }
    emit(state.copyWith(data: state.data.copyWith(templates: list)));
  }

  void delete(int id) => emit(state.copyWith(
      data: state.data.copyWith(
          templates: state.templates.where((d) => d.id != id).toList())));
}
