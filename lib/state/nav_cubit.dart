import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Every full screen of the app (the artifact's `S.v`).
enum AppView {
  home,
  search,
  myDesigns,
  studio,
  profile,
  templateDetail,
  editor,
  preview,
  wallet,
  sharedView,
  expiredLink;

  /// Bottom-tab screens.
  bool get isTab => const {
        AppView.home,
        AppView.search,
        AppView.myDesigns,
        AppView.studio,
        AppView.profile,
      }.contains(this);

  /// Tab screens that show the skeleton loading state when opened.
  bool get showsSkeleton =>
      this == AppView.home || this == AppView.search || this == AppView.myDesigns;
}

/// Bottom sheets / modals (the artifact's `S.sh`).
sealed class AppSheet {
  const AppSheet();
}

class RegisterSheet extends AppSheet {
  const RegisterSheet();
}

class NoCoinsSheet extends AppSheet {
  const NoCoinsSheet();
}

class UnlockSheet extends AppSheet {
  const UnlockSheet(this.designId);
  final int designId;
}

class SendCoinsSheet extends AppSheet {
  const SendCoinsSheet();
}

class DownloadedSheet extends AppSheet {
  const DownloadedSheet();
}

class ExportSheet extends AppSheet {
  const ExportSheet();
}

class ShareSheet extends AppSheet {
  const ShareSheet();
}

class LinkSheet extends AppSheet {
  const LinkSheet();
}

class ActionsSheet extends AppSheet {
  const ActionsSheet();
}

class InviteSheet extends AppSheet {
  const InviteSheet();
}

class ErrorSheet extends AppSheet {
  const ErrorSheet(this.label);
  final String label;
}

class ImageSearchSheet extends AppSheet {
  const ImageSearchSheet();
}

class NavState {
  const NavState({
    this.view = AppView.home,
    this.history = const [],
    this.sheet,
    this.loading = false,
    this.splash = true,
    this.intro = true,
    this.slowDemo = false,
    this.templateId = 1,
  });

  final AppView view;

  /// Screens to return to with the back button.
  final List<AppView> history;
  final AppSheet? sheet;

  /// Skeleton / "Loading…" state shown briefly when a tab opens.
  final bool loading;
  final bool splash;
  final bool intro;

  /// "Slow network loading screen" demo from the profile screen.
  final bool slowDemo;
  final int templateId;

  NavState copyWith({
    AppView? view,
    List<AppView>? history,
    Object? sheet = _keep,
    bool? loading,
    bool? splash,
    bool? intro,
    bool? slowDemo,
    int? templateId,
  }) {
    return NavState(
      view: view ?? this.view,
      history: history ?? this.history,
      sheet: identical(sheet, _keep) ? this.sheet : sheet as AppSheet?,
      loading: loading ?? this.loading,
      splash: splash ?? this.splash,
      intro: intro ?? this.intro,
      slowDemo: slowDemo ?? this.slowDemo,
      templateId: templateId ?? this.templateId,
    );
  }
}

const Object _keep = Object();

/// Navigation, modal sheets and the splash / intro overlays.
class NavCubit extends Cubit<NavState> {
  NavCubit() : super(const NavState());

  Timer? _loadTimer;
  Timer? _slowTimer;

  /// Switch to a bottom-tab screen.
  void tab(AppView view) {
    _loadTimer?.cancel();
    final loading = view.showsSkeleton;
    emit(NavState(
      view: view,
      history: const [],
      sheet: null,
      loading: loading,
      splash: state.splash,
      intro: state.intro,
      slowDemo: state.slowDemo,
      templateId: state.templateId,
    ));
    if (loading) {
      _loadTimer = Timer(const Duration(milliseconds: 600), () {
        if (!isClosed) emit(state.copyWith(loading: false));
      });
    }
  }

  /// Open a screen on top of the current one.
  void go(AppView view, {int? templateId}) {
    emit(state.copyWith(
      history: [...state.history, state.view],
      view: view,
      sheet: null,
      templateId: templateId,
    ));
  }

  /// The ← button: back to where the user came from (home by default).
  void back() {
    if (state.history.isEmpty) {
      emit(state.copyWith(view: AppView.home, sheet: null));
      return;
    }
    final h = [...state.history];
    final v = h.removeLast();
    emit(state.copyWith(view: v, history: h, sheet: null));
  }

  /// "Back to Editor" in the preview.
  void backToEditor() {
    final h = [...state.history];
    if (h.isNotEmpty && h.last == AppView.editor) h.removeLast();
    emit(state.copyWith(view: AppView.editor, history: h, sheet: null));
  }

  void openSheet(AppSheet sheet) => emit(state.copyWith(sheet: sheet));

  void closeSheet() {
    if (state.sheet != null) emit(state.copyWith(sheet: null));
  }

  void dismissSplash() {
    if (state.splash) emit(state.copyWith(splash: false));
  }

  void dismissIntro() {
    if (state.intro) emit(state.copyWith(intro: false));
  }

  /// Shows the full-screen "slow connection" state for a few seconds.
  void showSlowDemo() {
    _slowTimer?.cancel();
    emit(state.copyWith(slowDemo: true));
    _slowTimer = Timer(const Duration(milliseconds: 3500), () {
      if (!isClosed) emit(state.copyWith(slowDemo: false));
    });
  }

  @override
  Future<void> close() {
    _loadTimer?.cancel();
    _slowTimer?.cancel();
    return super.close();
  }
}
