import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/catalog.dart';
import '../state/catalog_cubit.dart';
import '../state/editor_cubit.dart';
import '../state/nav_cubit.dart';
import '../state/session_cubit.dart';
import '../state/settings_cubit.dart';
import '../state/studio_cubit.dart';
import 'app_controller.dart';
import 'app_shell.dart';
import 'app_theme.dart';

/// Root widget: wires the cubits, the [AppController] and the theme.
class MideaTouchApp extends StatelessWidget {
  const MideaTouchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => NavCubit()),
        BlocProvider(create: (_) => CatalogCubit()),
        BlocProvider(
          create: (c) => SessionCubit(
              seedDesigns:
                  Catalog.savedDesigns(c.read<CatalogCubit>().state.templates)),
        ),
        BlocProvider(create: (_) => EditorCubit()),
        BlocProvider(create: (_) => StudioCubit()),
        BlocProvider(create: (_) => SettingsCubit()),
        RepositoryProvider(
          lazy: false,
          create: (c) => AppController(
            nav: c.read<NavCubit>(),
            session: c.read<SessionCubit>(),
            catalog: c.read<CatalogCubit>(),
            editor: c.read<EditorCubit>(),
            studio: c.read<StudioCubit>(),
            settings: c.read<SettingsCubit>(),
          ),
        ),
      ],
      child: BlocBuilder<SettingsCubit, SettingsState>(
        buildWhen: (a, b) => a.themeMode != b.themeMode || a.lang != b.lang,
        builder: (context, s) => MaterialApp(
          title: 'Midas\'s Touch',
          debugShowCheckedModeBanner: false,
          themeMode: s.themeMode,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          locale: Locale(s.lang),
          supportedLocales: const [Locale('en'), Locale('hi')],
          localizationsDelegates: const [
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          home: const AppShell(),
        ),
      ),
    );
  }
}
