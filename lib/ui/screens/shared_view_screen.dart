import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../app/app_controller.dart';
import '../../core/theme/palette.dart';
import '../../state/editor_cubit.dart';
import '../../state/nav_cubit.dart';
import '../../state/settings_cubit.dart';
import '../widgets/common.dart';
import '../widgets/design_canvas.dart';
import '../widgets/kit.dart';

/// `shv`: what a recipient of a shared link sees.
class SharedViewScreen extends StatelessWidget {
  const SharedViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final t = context.watch<SettingsCubit>().state.t;
    final design = context.watch<EditorCubit>().state.design;
    if (design == null) return const SizedBox();
    return Column(children: [
      const ScreenHeader(children: [BrandLogo(height: 40)]),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: DesignCanvas(design: design)),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.2),
              child: Text(design.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, fontWeight: kBold)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.2),
              child: Text('By Sunrise Bakery',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: pal.mu)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                AppButton(t('share'),
                    onTap: () => context.app.shareSharedView(design)),
                const SizedBox(width: 8),
                AppButton('Download JPG',
                    style: BtnStyle.ghost, onTap: context.app.download),
              ]),
            ),
            Tap(
              onTap: () => context.read<NavCubit>().go(AppView.expiredLink),
              child: Text('Show expired link state',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: pal.mu)),
            ),
          ],
        ),
      ),
    ]);
  }
}

/// `xl`: the "link expired" empty state.
class ExpiredLinkScreen extends StatelessWidget {
  const ExpiredLinkScreen({super.key});

  @override
  Widget build(BuildContext context) => Column(children: [
        const BackHeader('Shared link'),
        Expanded(
          child: ListView(padding: EdgeInsets.zero, children: [
            EmptyState(
              title: 'This link is no longer available.',
              message:
                  'The creative may have been removed or the link has expired.',
              buttonLabel: 'Create your own',
              onButton: () => context.app.use(1),
            ),
          ]),
        ),
      ]);
}
