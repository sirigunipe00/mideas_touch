import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../app/app_controller.dart';
import '../../core/theme/css_gradient.dart';
import '../../core/theme/palette.dart';
import '../../core/l10n/strings.dart';
import '../../data/catalog.dart';
import '../../state/catalog_cubit.dart';
import '../../state/nav_cubit.dart';
import '../../state/session_cubit.dart';
import '../../state/settings_cubit.dart';
import '../widgets/coin.dart';
import '../widgets/common.dart';
import '../widgets/kit.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Column(children: [
      const ScreenHeader(children: [
        BrandLogo(height: 44),
        Spacer(),
        LanguageSwitch(),
        ThemeToggleButton(),
      ]),
      Expanded(
        child: BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, settings) {
            final t = settings.t;
            return ListView(padding: EdgeInsets.zero, children: [
              // Search bar
              Tap(
                onTap: () => context.app.tab(AppView.search),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: pal.c,
                    border: Border.all(color: pal.ln),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text('⌕ ${t('ph')}',
                      style: TextStyle(color: pal.mu)),
                ),
              ),
              const _CoinsChip(),
              _BannerPager(strings: t),
              SectionTitle(t('cat'), top: 6),
              const _CategoryChips(),
              BlocBuilder<CatalogCubit, CatalogState>(
                builder: (context, cat) {
                  final all = cat.templates;
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DesignSection(
                            title: t('pop'), designs: _slice(all, 0, 4)),
                        DesignSection(
                            title: t('trend'), designs: _slice(all, 2, 6)),
                        DesignSection(
                            title: t('rec'), designs: _slice(all, 4, null)),
                      ]);
                },
              ),
              const SizedBox(height: 16),
            ]);
          },
        ),
      ),
      const BottomTabs(),
    ]);
  }
}

List<T> _slice<T>(List<T> l, int from, int? to) {
  if (from >= l.length) return [];
  return l.sublist(from, (to ?? l.length).clamp(from, l.length));
}

/// `CC()`: the "🪙 N coins · Get coins ›" chip.
class _CoinsChip extends StatelessWidget {
  const _CoinsChip();

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return BlocBuilder<SessionCubit, SessionState>(
      builder: (context, s) => Tap(
        onTap: context.app.openWallet,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: pal.pl,
            border: Border.all(color: pal.p),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CoinText(s.signedIn ? '🪙 ${s.coins} coins' : '🪙 Coins',
                  style: TextStyle(fontWeight: kSemi, color: pal.tx)),
              Flexible(
                child: Text(
                    s.signedIn ? 'Get coins ›' : 'Register to start ›',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: kSemi, color: pal.pd)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips();

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
        child: Row(children: [
          for (var i = 0; i < Catalog.categories.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            CategoryChip(Catalog.categories[i],
                onTap: () =>
                    context.app.chooseCategory(Catalog.categories[i])),
          ]
        ]),
      );
}

class _Slide {
  const _Slide(this.colors, this.tag, this.title, this.body, this.button,
      this.action,
      {this.dark = false});
  final List<Color> colors;
  final String tag;
  final String title;
  final String body;
  final String button;
  final BannerAction action;
  final bool dark;
}

List<_Slide> _slides(Strings t) => [
      _Slide([hex('#efbf05'), hex('#f6da6f')], t('tag'), t('h1'), t('sub'),
          t('start'), BannerAction.startCreating),
      _Slide([hex('#f6da6f'), hex('#faeaac')], '🪙 Earn free coins',
          'Follow, refer and tag to earn coins', '1 coin for each action.',
          'Earn coins', BannerAction.earnCoins),
      _Slide([hex('#1d1700'), hex('#4a3c0c')], 'Buy coins',
          'Get up to 15 coins for ₹100',
          '₹10 for 1 coin. Bigger packs give bonus coins.', 'See packs',
          BannerAction.seePacks,
          dark: true),
      _Slide([hex('#e8a20a'), hex('#efbf05')], 'Festival season',
          'Festive designs are here', 'Explore for free. Customise with 1 coin.',
          'Explore', BannerAction.explore),
    ];

/// `BANNERS()`: swipeable hero banners with dots and 3.5s auto-advance.
class _BannerPager extends StatefulWidget {
  const _BannerPager({required this.strings});

  final Strings strings;

  @override
  State<_BannerPager> createState() => _BannerPagerState();
}

class _BannerPagerState extends State<_BannerPager> {
  final _controller = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 3500), (_) {
      if (!mounted || !_controller.hasClients) return;
      final nav = context.read<NavCubit>().state;
      if (nav.view != AppView.home || nav.sheet != null || nav.intro) return;
      _controller.animateToPage((_index + 1) % 4,
          duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final slides = _slides(widget.strings);
    return Column(children: [
      const SizedBox(height: 12),
      Stack(fit: StackFit.passthrough, children: [
        // Invisible copies size the pager to the tallest slide.
        for (final s in slides)
          Visibility(
            visible: false,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: _SlideCard(s),
          ),
        Positioned.fill(
          child: PageView(
            controller: _controller,
            onPageChanged: (i) => setState(() => _index = i),
            children: [for (final s in slides) _SlideCard(s)],
          ),
        ),
      ]),
      Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < slides.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: i == _index ? 20 : 7,
              height: 7,
              decoration: BoxDecoration(
                  color: i == _index ? pal.p : pal.ln,
                  borderRadius: BorderRadius.circular(9)),
            ),
          ]
        ]),
      ),
    ]);
  }
}

class _SlideCard extends StatelessWidget {
  const _SlideCard(this.slide);

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final color = slide.dark ? const Color(0xFFFCF4D3) : Brand.ink;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        constraints: const BoxConstraints(minHeight: 180),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: CssLinearGradient(135, slide.colors),
          borderRadius: BorderRadius.circular(24),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: color),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                CoinText(slide.tag,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: kSemi, height: 20.3 / 11)),
                const SizedBox(height: 4.4),
                Text(slide.title,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: kBold,
                        height: 1.2,
                        leadingDistribution: TextLeadingDistribution.even)),
                const SizedBox(height: 4.4),
                Text(slide.body, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 3.9),
                AppButton(slide.button,
                    small: true,
                    background: slide.dark ? Brand.gold : Brand.ink,
                    foreground: slide.dark ? Brand.ink : const Color(0xFFFCF4D3),
                    onTap: () => context.app.runBannerAction(slide.action)),
              ]),
        ),
      ),
    );
  }
}
