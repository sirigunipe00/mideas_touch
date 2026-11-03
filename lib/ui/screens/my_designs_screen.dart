import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../app/app_controller.dart';
import '../../core/theme/palette.dart';
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
    final loading = context.select<NavCubit, bool>((c) => c.state.loading);
    final pal = context.pal;
    final f = s.myDesignsFilter;
    final list = f == 'Recent'
        ? s.designs
        : s.designs.where((d) => '${d.status}s' == f || d.status == f).toList();

    Widget body;
    if (loading) {
      body = Column(children: [
        for (var i = 0; i < 3; i++)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Skeleton(height: 84),
          ),
      ]);
    } else if (s.designs.isEmpty) {
      body = EmptyState(
        title: 'You haven’t created any designs yet.',
        message: 'Your designs will appear here.',
        buttonLabel: t('start'),
        onButton: () => context.app.use(1),
      );
    } else if (list.isEmpty) {
      body = const EmptyState(
          title: 'Nothing here yet', message: 'Your designs will appear here.');
    } else {
      body = Column(children: [
        for (final d in list)
          ListCard(children: [
            Tap(
              onTap: () => context.app.editSaved(d.id),
              child: SizedBox(
                width: 64,
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: DesignCanvas(design: d)),
              ),
            ),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.name, style: const TextStyle(fontWeight: kSemi)),
                    Tag(d.status),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.2),
                      child: Text('Last edited: ${d.mod}',
                          style: TextStyle(fontSize: 12, color: pal.mu)),
                    ),
                  ]),
            ),
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
        options: const ['Recent', 'Drafts', 'Completed'],
        selected: f,
        onChanged: context.read<SessionCubit>().setFilter,
      ),
      Expanded(
          child: ListView(padding: EdgeInsets.zero, children: [body])),
      const BottomTabs(),
    ]);
  }
}
