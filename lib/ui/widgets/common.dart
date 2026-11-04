import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../app/app_controller.dart';
import '../../core/constants/layout.dart';
import '../../core/theme/palette.dart';
import '../../models/catalog_models.dart';
import '../../models/design_model.dart';
import '../../state/catalog_cubit.dart';
import '../../state/nav_cubit.dart';
import '../../state/session_cubit.dart';
import '../../state/settings_cubit.dart';
import 'coin.dart';
import 'design_canvas.dart';
import 'kit.dart';

/// The Midas's Touch logo (light / dark artwork).
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, required this.height, this.forceLight = false});

  final double height;
  final bool forceLight;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark && !forceLight;
    return Image.asset(
      'assets/images/brand_${dark ? 'dark' : 'light'}.png',
      height: height,
      fit: BoxFit.fitHeight,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Midas\'s Touch',
    );
  }
}

/// `.lg`: English / हिन्दी switch.
class LanguageSwitch extends StatelessWidget {
  const LanguageSwitch({super.key, this.expand = false});

  /// In the profile the pill is a block-level flex box and spans the row.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, s) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
            color: pal.pl, borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, children: [
          for (final o in const [('en', 'English'), ('hi', 'हिन्दी')])
            Tap(
              onTap: () => context.read<SettingsCubit>().setLanguage(o.$1),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                    color: s.lang == o.$1 ? pal.p : null,
                    borderRadius: BorderRadius.circular(99)),
                child: Text(o.$2,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: s.lang == o.$1 ? kSemi : FontWeight.w400,
                        color: s.lang == o.$1 ? pal.pt : pal.tx)),
              ),
            ),
        ]),
      ),
    );
  }
}

/// `THB`: light / dark toggle button.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return IconBox(
      label: 'Toggle theme',
      onTap: () => context
          .read<SettingsCubit>()
          .setThemeMode(dark ? ThemeMode.light : ThemeMode.dark),
      child: Text(dark ? '☀' : '☾'),
    );
  }
}

/// `.hd`: screen header row.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.gap = 8,
  });

  final List<Widget> children;
  final EdgeInsets padding;
  final double gap;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: padding,
        child: Row(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            children[i],
          ]
        ]),
      );
}

/// Header with a title only (My Designs, Profile, Studio).
class TitleHeader extends StatelessWidget {
  const TitleHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => ScreenHeader(children: [
        Text(title,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: kBold,
                height: 1.2,
                leadingDistribution: TextLeadingDistribution.even)),
      ]);
}

/// `hd(title)`: back arrow + title.
class BackHeader extends StatelessWidget {
  const BackHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => ScreenHeader(children: [
        IconBox(
            label: 'Back',
            onTap: context.read<NavCubit>().back,
            child: const Text('←')),
        Expanded(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: kSemi))),
      ]);
}

/// `.tabs`: bottom navigation.
class BottomTabs extends StatelessWidget {
  const BottomTabs({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return BlocBuilder<SessionCubit, SessionState>(
      builder: (context, session) => BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, settings) => BlocBuilder<NavCubit, NavState>(
          builder: (context, nav) {
            final tabs = <(AppView, String, String)>[
              (AppView.home, 'home', '⌂'),
              (AppView.search, 'se', '⌕'),
              (AppView.myDesigns, 'md', '▤'),
              if (session.isCreator) (AppView.studio, 'studio', '✚'),
              (AppView.profile, 'me', '☺'),
            ];
            return Container(
              padding: const EdgeInsets.only(top: 6, bottom: 10),
              decoration: BoxDecoration(
                color: pal.c,
                border: Border(top: BorderSide(color: pal.ln)),
              ),
              child: Row(children: [
                for (final t in tabs)
                  Expanded(
                    child: Tap(
                      onTap: () => context.app.tab(t.$1),
                      label: settings.t(t.$2),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(t.$3,
                            style: TextStyle(
                                fontSize: 20,
                                color:
                                    nav.view == t.$1 ? pal.pd : pal.mu,
                                fontWeight: nav.view == t.$1
                                    ? kBold
                                    : FontWeight.w400)),
                        Text(settings.t(t.$2),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 10,
                                color: nav.view == t.$1 ? pal.pd : pal.mu,
                                fontWeight: nav.view == t.$1
                                    ? kBold
                                    : FontWeight.w400)),
                      ]),
                    ),
                  ),
              ]),
            );
          },
        ),
      ),
    );
  }
}

/// `bdg(d)`: the "🪙 1" / "✓ Unlocked" badge on a design.
class DesignBadge extends StatelessWidget {
  const DesignBadge(this.design, {super.key});

  final DesignModel design;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return BlocBuilder<SessionCubit, SessionState>(builder: (context, s) {
      final locked = s.isLocked(design);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
        decoration: BoxDecoration(
            color: locked ? pal.p : Brand.freeGreen,
            borderRadius: BorderRadius.circular(99)),
        child: CoinText(locked ? '🪙 1' : '✓ Unlocked',
            style: TextStyle(
                fontSize: 11,
                fontWeight: kBold,
                color: locked ? pal.pt : Brand.freeGreenInk)),
      );
    });
  }
}

/// A design thumbnail with its badge (`th(d)` + `bdg(d)`).
class BadgedThumb extends StatelessWidget {
  const BadgedThumb(this.design, {super.key});

  final DesignModel design;

  @override
  Widget build(BuildContext context) => Stack(children: [
        DesignCanvas(design: design),
        Positioned(top: 8, left: 8, child: DesignBadge(design)),
      ]);
}

/// `.mc`: design card used in carousels.
class DesignCard extends StatelessWidget {
  const DesignCard(this.design, {super.key, this.width = 150, this.compact = false});

  final DesignModel design;
  final double width;

  /// Editor "Designs" tool: thumbnails only, no title.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return SizedBox(
      width: width,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
            color: pal.c,
            borderRadius: BorderRadius.circular(18),
            boxShadow: pal.sh),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          BadgedThumb(design),
          if (!compact)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(design.name,
                        style:
                            const TextStyle(fontWeight: kSemi, fontSize: 14)),
                    Text(design.cat,
                        style: TextStyle(fontSize: 11.67, color: pal.mu)),
                    const SizedBox(height: 6),
                  ]),
            ),
        ]),
      ),
    );
  }
}

/// Horizontal list of cards (`.car`).
class CardRow extends StatelessWidget {
  const CardRow({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding ?? const EdgeInsets.fromLTRB(16, 0, 16, 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            children[i],
          ]
        ]),
      );
}

/// `sec(title, list)`: heading + carousel (skeletons while loading).
class DesignSection extends StatelessWidget {
  const DesignSection({super.key, required this.title, required this.designs});

  final String title;
  final List<DesignModel> designs;

  @override
  Widget build(BuildContext context) {
    final loading = context.select<NavCubit, bool>((c) => c.state.loading) ||
        context.select<CatalogCubit, bool>((c) => c.state.loading);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle(title),
      if (loading)
        const CardRow(children: [
          Skeleton(width: 150, height: 210),
          Skeleton(width: 150, height: 210),
          Skeleton(width: 150, height: 210),
        ])
      else
        CardRow(children: [
          for (final d in designs)
            Tap(
                onTap: () => context.app.openTemplate(d.id),
                child: DesignCard(d)),
        ]),
    ]);
  }
}

/// One emoji tile of the stock-asset grids (`.ag a`).
class AssetCell extends StatelessWidget {
  const AssetCell(this.emoji,
      {super.key, this.onTap, this.on = false, this.fontSize = 30, this.height});

  final String emoji;
  final VoidCallback? onTap;
  final bool on;
  final double fontSize;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Tap(
      onTap: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.all(6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: pal.c,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: on ? pal.p : pal.ln, width: on ? 2 : 1),
        ),
        child: Text(emoji,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: fontSize)),
      ),
    );
  }
}

/// `.ag` / `.st`: a grid of equally sized cells (see [kMatchRenderedGrid]).
class ArtifactGrid extends StatelessWidget {
  const ArtifactGrid({
    super.key,
    required this.columns,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final int columns;
  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final cols = kMatchRenderedGrid ? 1 : columns;
    return Padding(
      padding: padding,
      child: LayoutBuilder(builder: (context, c) {
        final w = (c.maxWidth - (cols - 1) * 8) / cols;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final ch in children) SizedBox(width: w, child: ch)],
        );
      }),
    );
  }
}

/// Plain muted paragraph (`p.mu`).
class MutedText extends StatelessWidget {
  const MutedText(this.text,
      {super.key, this.size, this.align, this.padding = const EdgeInsets.symmetric(vertical: 4.2)});

  final String text;
  final double? size;
  final TextAlign? align;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: CoinText(text,
            textAlign: align,
            style: TextStyle(color: context.pal.mu, fontSize: size)),
      );
}

/// Convenience for stock-asset lookups.
List<int> matchingAssetIndexes(List<StockAsset> assets, String query) {
  final q = query.toLowerCase();
  return [
    for (var i = 0; i < assets.length; i++)
      if (assets[i].keywords.contains(q)) i
  ];
}
