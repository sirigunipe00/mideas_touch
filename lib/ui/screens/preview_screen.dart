import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../app/app_controller.dart';
import '../../models/design_model.dart';
import '../../state/editor_cubit.dart';
import '../../state/nav_cubit.dart';
import '../../state/settings_cubit.dart';
import '../widgets/common.dart';
import '../widgets/design_canvas.dart';
import '../widgets/kit.dart';
import '../widgets/stage.dart';

/// `PV()`: full-screen preview on a dark background.
class PreviewScreen extends StatelessWidget {
  const PreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<SettingsCubit>().state.t;
    final design =
        context.select<EditorCubit, DesignModel?>((c) => c.state.design);
    return Container(
      color: const Color(0xFF0F0D04),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: Column(children: [
          ScreenHeader(children: [
            IconBox(
              label: 'Back',
              borderless: true,
              background: const Color(0xFF33290A),
              foreground: Colors.white,
              onTap: context.read<NavCubit>().backToEditor,
              child: const Text('←'),
            ),
            const Expanded(
                child: Text('Back to Editor',
                    style: TextStyle(fontWeight: kSemi))),
            AppButton(t('exp'), small: true, onTap: context.app.openExport),
            AppButton(t('share'),
                small: true,
                style: BtnStyle.ghost,
                onTap: () =>
                    context.read<NavCubit>().openSheet(const ShareSheet())),
          ]),
          Expanded(
            child: design == null
                ? const SizedBox()
                : Stage(
                    checkerboard: false,
                    canvasRadius: 8,
                    builder: (_, __) => DesignCanvas(design: design),
                  ),
          ),
        ]),
      ),
    );
  }
}
