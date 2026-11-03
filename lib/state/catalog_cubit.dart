import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/catalog.dart';
import '../models/design_model.dart';

class CatalogState {
  const CatalogState({required this.templates, this.query = ''});

  /// All templates (`T`), including those published from the Studio.
  final List<DesignModel> templates;

  /// Search text (`S.q`).
  final String query;

  DesignModel? byId(int id) {
    for (final d in templates) {
      if (d.id == id) return d;
    }
    return null;
  }

  /// Templates created by the signed-in creator (`my()`).
  List<DesignModel> get mine => templates.where((d) => d.by == 'You').toList();

  CatalogState copyWith({List<DesignModel>? templates, String? query}) =>
      CatalogState(
          templates: templates ?? this.templates, query: query ?? this.query);
}

/// The template catalog and the search query.
class CatalogCubit extends Cubit<CatalogState> {
  CatalogCubit() : super(CatalogState(templates: Catalog.templates()));

  void setQuery(String q) => emit(state.copyWith(query: q));

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
    emit(state.copyWith(templates: list));
  }

  void delete(int id) => emit(state.copyWith(
      templates: state.templates.where((d) => d.id != id).toList()));
}
