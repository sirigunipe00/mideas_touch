import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../app/app_controller.dart';
import '../../core/theme/palette.dart';
import '../../models/design_model.dart';
import '../../state/catalog_cubit.dart';
import '../../state/nav_cubit.dart';
import '../../state/session_cubit.dart';
import '../../state/settings_cubit.dart';
import '../widgets/common.dart';
import '../widgets/design_canvas.dart';
import '../widgets/kit.dart';

class MyDesignsScreen extends StatelessWidget {
  const MyDesignsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<SettingsCubit>().state.t;
    final s = context.watch<SessionCubit>().state;
    final catalog = context.watch<CatalogCubit>().state;
    final loading = context.select<NavCubit, bool>((c) => c.state.loading) ||
        catalog.loading;
    final pal = context.pal;
    final f = const {'Unlocked', 'Draft', 'Shared'}.contains(s.myDesignsFilter)
        ? s.myDesignsFilter
        : 'Unlocked';

    // Unlocked = catalogue templates the user has unlocked (not saved drafts).
    // Draft / Shared = the user's own saved designs by status.
    final List<DesignModel> list;
    final unlockedTemplates = catalog.templates
        .where((d) => !s.isLocked(d))
        .toList();
    switch (f) {
      case 'Unlocked':
        list = unlockedTemplates;
      case 'Draft':
        list = s.designs.where((d) => d.status == 'Draft').toList();
      case 'Shared':
        list = s.designs
            .where((d) => d.status == 'Completed' || d.status == 'Shared')
            .toList();
      default:
        list = unlockedTemplates;
    }

    final showingUnlocked = f == 'Unlocked';

    Widget body;
    if (loading) {
      body = Column(children: [
        for (var i = 0; i < 3; i++)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Skeleton(height: 84),
          ),
      ]);
    } else if (list.isEmpty) {
      body = EmptyState(
        title: showingUnlocked
            ? 'No unlocked designs yet'
            : f == 'Draft'
                ? 'No drafts yet'
                : 'Nothing shared yet',
        message: showingUnlocked
            ? 'Unlock a design with 1 coin to see it here.'
            : 'Your designs will appear here.',
        buttonLabel: showingUnlocked ? t('start') : null,
        onButton:
            showingUnlocked ? () => context.app.tab(AppView.home) : null,
      );
    } else {
      body = Column(children: [
        for (final d in list)
          ListCard(children: [
            Expanded(
              child: Tap(
                onTap: () => showingUnlocked
                    ? context.app.use(d.id)
                    : context.app.editSaved(d.id),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 64,
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: DesignCanvas(design: d)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: kSemi)),
                            Tag(showingUnlocked
                                ? 'Unlocked'
                                : (d.status == 'Completed'
                                    ? 'Shared'
                                    : d.status)),
                            if (!showingUnlocked)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4.2),
                                child: Text('Last edited: ${d.mod}',
                                    style:
                                        TextStyle(fontSize: 12, color: pal.mu)),
                              ),
                          ]),
                    ),
                  ],
                ),
              ),
            ),
            if (!showingUnlocked)
              IconBox(
                  label: 'More',
                  onTap: () => context.app.openActions(d),
                  child: const Text('⋯')),
          ]),
      ]);
    }

    return Column(children: [
      TitleHeader(t('md')),
      Segmented(
        options: const ['Unlocked', 'Draft', 'Shared'],
        selected: f,
        onChanged: context.read<SessionCubit>().setFilter,
      ),
      Expanded(
          child: ListView(padding: EdgeInsets.zero, children: [body])),
      const BottomTabs(),
    ]);
  }
}
