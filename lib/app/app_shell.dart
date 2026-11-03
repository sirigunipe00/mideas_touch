import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/constants/layout.dart';
import '../core/theme/palette.dart';
import '../state/nav_cubit.dart';
import '../ui/overlays/overlays.dart';
import '../ui/screens/editor_screen.dart';
import '../ui/screens/home_screen.dart';
import '../ui/screens/my_designs_screen.dart';
import '../ui/screens/preview_screen.dart';
import '../ui/screens/profile_screen.dart';
import '../ui/screens/search_screen.dart';
import '../ui/screens/shared_view_screen.dart';
import '../ui/screens/studio_screen.dart';
import '../ui/screens/template_detail_screen.dart';
import '../ui/screens/wallet_screen.dart';
import '../ui/sheets/sheets.dart';
import 'app_controller.dart';

/// The "phone": full-bleed on handsets, a framed 430px column on wide
/// windows (`.ph` in the artifact).
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();
    // The splash dismisses itself after 3 seconds (or on tap).
    _splashTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) context.read<NavCubit>().dismissSplash();
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
  }

  void _onBack(NavState nav) {
    final cubit = context.read<NavCubit>();
    if (nav.splash) {
      cubit.dismissSplash();
    } else if (nav.intro) {
      return;
    } else if (nav.sheet != null) {
      cubit.closeSheet();
    } else if (nav.view == AppView.preview) {
      cubit.backToEditor();
    } else if (nav.history.isNotEmpty || !nav.view.isTab) {
      cubit.back();
    } else if (nav.view != AppView.home) {
      context.app.tab(AppView.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final nav = context.watch<NavCubit>().state;
    final atRoot = nav.splash == false &&
        nav.intro == false &&
        nav.sheet == null &&
        nav.history.isEmpty &&
        nav.view == AppView.home;

    final phone = _Phone(nav: nav);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (context.isDark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark)
          .copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: pal.bd),
      child: PopScope(
        canPop: atRoot,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _onBack(nav);
        },
        child: Scaffold(
          backgroundColor: pal.bd,
          body: LayoutBuilder(builder: (context, c) {
            final framed = c.maxWidth >= 500;
            if (!framed) return SafeArea(child: phone);
            final h = (c.maxHeight - 32).clamp(0.0, 860.0);
            return Center(
              child: Container(
                width: kPhoneMaxWidth + 16,
                height: h,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(38),
                ),
                padding: const EdgeInsets.all(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      removeBottom: true,
                      child: phone),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _Phone extends StatelessWidget {
  const _Phone({required this.nav});

  final NavState nav;

  Widget _screen(AppView v) => switch (v) {
        AppView.home => const HomeScreen(),
        AppView.search => const SearchScreen(),
        AppView.myDesigns => const MyDesignsScreen(),
        AppView.studio => const StudioScreen(),
        AppView.profile => const ProfileScreen(),
        AppView.templateDetail => const TemplateDetailScreen(),
        AppView.editor => const EditorScreen(),
        AppView.preview => const PreviewScreen(),
        AppView.wallet => const WalletScreen(),
        AppView.sharedView => const SharedViewScreen(),
        AppView.expiredLink => const ExpiredLinkScreen(),
      };

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      color: pal.bg,
      child: Stack(children: [
        Positioned.fill(
            child: KeyedSubtree(
                key: ValueKey(nav.view), child: _screen(nav.view))),
        if (!nav.splash && nav.intro)
          const Positioned.fill(child: IntroOverlay())
        else if (!nav.splash)
          const Positioned.fill(child: SheetOverlay()),
        if (nav.loading && !nav.splash) const LoadingPill(),
        const ToastHost(),
        if (nav.slowDemo) const Positioned.fill(child: SlowNetworkOverlay()),
        if (nav.splash) const Positioned.fill(child: SplashOverlay()),
      ]),
    );
  }
}
