import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../app/app_controller.dart';
import '../../state/catalog_cubit.dart';
import '../../state/nav_cubit.dart';
import '../widgets/common.dart';
import '../widgets/kit.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _q;

  @override
  void initState() {
    super.initState();
    _q = TextEditingController(text: context.read<CatalogCubit>().state.query);
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ScreenHeader(children: [
        Expanded(
          child: Row(children: [
            Expanded(
              child: AppField(
                controller: _q,
                hint: 'Search designs...',
                onChanged: context.read<CatalogCubit>().setQuery,
              ),
            ),
            const SizedBox(width: 8),
            IconBox(
              label: 'Search by image',
              onTap: () =>
                  context.read<NavCubit>().openSheet(const ImageSearchSheet()),
              child: const Text('📷'),
            ),
          ]),
        ),
      ]),
      const Expanded(child: _Results()),
      const BottomTabs(),
    ]);
  }
}

class _Results extends StatelessWidget {
  const _Results();

  @override
  Widget build(BuildContext context) {
    final navLoading = context.select<NavCubit, bool>((c) => c.state.loading);
    final cat = context.watch<CatalogCubit>().state;
    if (cat.status == CatalogStatus.error) {
      return ListView(padding: EdgeInsets.zero, children: [
        EmptyState(
          title: 'Couldn’t load designs',
          message: cat.error,
          buttonLabel: 'Try again',
          onButton: context.read<CatalogCubit>().load,
        ),
      ]);
    }
    if (navLoading || cat.loading) {
      return ListView(padding: EdgeInsets.zero, children: const [
        CardRow(
          padding: EdgeInsets.all(16),
          children: [
            Skeleton(width: 150, height: 210),
            Skeleton(width: 150, height: 210),
          ],
        ),
      ]);
    }
    final q = cat.query.toLowerCase();
    final designs = cat.templates
        .where((d) => ('${d.name}${d.cat}${d.desc}').toLowerCase().contains(q))
        .toList();
    if (designs.isEmpty) {
      return ListView(padding: EdgeInsets.zero, children: const [
        EmptyState(title: 'No designs found', message: 'Try another search.'),
      ]);
    }
    return ListView(padding: EdgeInsets.zero, children: [
      const SectionTitle('Designs'),
      CardRow(children: [
        for (final d in designs)
          Tap(
              onTap: () => context.app.openTemplate(d.id),
              child: DesignCard(d)),
      ]),
    ]);
  }
}
