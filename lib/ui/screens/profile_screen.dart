import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../app/app_controller.dart';
import '../../core/theme/palette.dart';
import '../../state/nav_cubit.dart';
import '../../state/session_cubit.dart';
import '../../state/settings_cubit.dart';
import '../widgets/coin.dart';
import '../widgets/common.dart';
import '../widgets/kit.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const _errors = [
    'Network error',
    'Search error',
    'Export error',
    'Save error',
    'Share-link generation error',
  ];

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final settings = context.watch<SettingsCubit>().state;
    final s = context.watch<SessionCubit>().state;
    final t = settings.t;
    final themeLabel = switch (settings.themeMode) {
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
      ThemeMode.system => 'System',
    };
    final user = s.user;
    return Column(children: [
      TitleHeader(t('me')),
      Expanded(
        child: ListView(padding: EdgeInsets.zero, children: [
          if (user != null) ...[
            ListCard(children: [
              GestureDetector(
                onLongPress: context.app.toggleCreatorMode,
                child: Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: pal.p, shape: BoxShape.circle),
                  child: Text(
                      user.name.isEmpty ? '' : user.name[0].toUpperCase(),
                      style: TextStyle(
                          fontSize: 16, fontWeight: kBold, color: pal.pt)),
                ),
              ),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name,
                          style: const TextStyle(fontWeight: kSemi)),
                      Tag(user.isCreator ? 'Creator' : 'Customer'),
                    ]),
              ),
            ]),
            MenuRow(
              onTap: () => context.read<NavCubit>().go(AppView.wallet),
              trailing: Text('${s.coins} ›',
                  style: const TextStyle(fontWeight: kSemi)),
              child: const CoinText('🪙 My Coins'),
            ),
          ] else
            EmptyState(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              title: 'You’re browsing as a guest',
              message: 'Register to customise with coins and download your designs.',
              buttonLabel: 'Register / Login',
              onButton: () => context.app.need(() {}),
            ),
          const SectionTitle('Theme'),
          Segmented(
            options: const ['Light', 'Dark', 'System'],
            selected: themeLabel,
            onChanged: (v) => context.read<SettingsCubit>().setThemeMode(
                switch (v) {
                  'Light' => ThemeMode.light,
                  'Dark' => ThemeMode.dark,
                  _ => ThemeMode.system,
                }),
          ),
          const SectionTitle('Language'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: LanguageSwitch(expand: true),
          ),
          const SectionTitle('States gallery'),
          for (final e in _errors)
            MenuRow(
              onTap: () => context.read<NavCubit>().openSheet(ErrorSheet(e)),
              trailing: const Text('›'),
              child: Text(e),
            ),
          MenuRow(
            onTap: () => context.read<NavCubit>().go(AppView.expiredLink),
            trailing: const Text('›'),
            child: const Text('Expired shared link'),
          ),
          MenuRow(
            onTap: context.read<NavCubit>().showSlowDemo,
            trailing: const Text('›'),
            child: const Text('Slow network loading screen'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(children: [
              if (user != null)
                AppButton('Log out',
                    style: BtnStyle.ghost, wide: true, onTap: context.app.logout),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(child: BrandLogo(height: 48)),
              ),
            ]),
          ),
        ]),
      ),
      const BottomTabs(),
    ]);
  }
}
