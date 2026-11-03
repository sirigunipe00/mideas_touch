import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../app/app_controller.dart';
import '../../core/theme/palette.dart';
import '../../state/catalog_cubit.dart';
import '../../state/nav_cubit.dart';
import '../../state/session_cubit.dart';
import '../../state/settings_cubit.dart';
import '../widgets/common.dart';
import '../widgets/kit.dart';

class TemplateDetailScreen extends StatelessWidget {
  const TemplateDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final id = context.select<NavCubit, int>((c) => c.state.templateId);
    final catalog = context.watch<CatalogCubit>().state;
    final session = context.watch<SessionCubit>().state;
    final settings = context.watch<SettingsCubit>().state;
    final d = catalog.byId(id);
    if (d == null) {
      return const Column(children: [BackHeader('')]);
    }
    final locked = session.isLocked(d);
    final desc = d.desc.isEmpty ? 'A ready-made promotional creative.' : d.desc;
    return Column(children: [
      BackHeader(d.name),
      Expanded(
        child: ListView(padding: EdgeInsets.zero, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20), boxShadow: pal.sh),
                clipBehavior: Clip.antiAlias,
                child: BadgedThumb(d),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5.2),
                child: Text(d.name,
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: kBold,
                        height: 1.2,
                        leadingDistribution: TextLeadingDistribution.even)),
              ),
              Text.rich(TextSpan(children: [
                WidgetSpan(
                    alignment: PlaceholderAlignment.middle, child: Tag(d.cat)),
                const TextSpan(text: ' '),
                TextSpan(
                    text: 'By ${d.by}',
                    style: TextStyle(fontSize: 12, color: pal.mu)),
              ])),
              MutedText(
                  '$desc A ready-made promotional creative that can be customized with your own text and images.'),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(children: [
                  Expanded(
                    child: AppButton(
                      locked ? '🪙 Customise · 1 coin' : settings.t('cust'),
                      wide: true,
                      onTap: () => context.app.use(d.id),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppButton('⬇ ${settings.t.downloadLabel}',
                      style: BtnStyle.ghost,
                      onTap: () => context.app.downloadTemplate(d.id)),
                ]),
              ),
            ]),
          ),
          DesignSection(
            title: 'Related Designs',
            designs: catalog.templates
                .where((x) => x.id != d.id)
                .take(4)
                .toList(),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    ]);
  }
}
