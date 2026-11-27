import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../app/app_controller.dart';
import '../../core/theme/palette.dart';
import '../../state/catalog_cubit.dart';
import '../../state/nav_cubit.dart';
import '../widgets/common.dart';
import '../widgets/kit.dart';

/// Quick-pick search categories shown above the bottom search bar.
const _searchCategories = [
  'Wishes',
  'Happy birthday',
  'Love',
  'Anniversary',
  'Congratulation',
  'Sorry',
  'Graduation',
  'Festival',
];

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

  void _applyQuery(String value) {
    _q.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    context.read<CatalogCubit>().setQuery(value);
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final query = context.select<CatalogCubit, String>((c) => c.state.query);
    // Keep the field in sync when a category is chosen from Home.
    if (_q.text != query && !FocusScope.of(context).hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _q.text != query) {
          _q.value = TextEditingValue(
            text: query,
            selection: TextSelection.collapsed(offset: query.length),
          );
        }
      });
    }
    return Column(children: [
      const Expanded(child: _Results()),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('Category',
              style: TextStyle(fontSize: 16, fontWeight: kBold, color: pal.tx)),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final label in _searchCategories)
              _SearchCategoryChip(
                label: label,
                selected: query.toLowerCase() == label.toLowerCase(),
                onTap: () => _applyQuery(label),
              ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
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
      const BottomTabs(),
    ]);
  }
}

class _SearchCategoryChip extends StatelessWidget {
  const _SearchCategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Tap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? pal.p : pal.c,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: pal.p, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: kSemi,
            color: selected ? pal.pt : pal.tx,
          ),
        ),
      ),
    );
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
