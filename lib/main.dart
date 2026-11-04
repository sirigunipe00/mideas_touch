import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app.dart';
import 'data/supabase/supabase_auth_repository.dart';
import 'data/supabase/supabase_catalog_repository.dart';
import 'data/supabase/supabase_config.dart';
import 'data/supabase/supabase_dns.dart';
import 'data/supabase/supabase_user_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  if (!SupabaseConfig.isConfigured) {
    runApp(const _MissingConfigApp());
    return;
  }
  // The local DNS sometimes answers supabase.co with an unusable address.
  installSupabaseDns(SupabaseConfig.url);
  await SupabaseConfig.initialize();
  final client = Supabase.instance.client;
  runApp(MideaTouchApp(
    catalogRepository: SupabaseCatalogRepository(client),
    authRepository: SupabaseAuthRepository(client),
    userRepository: SupabaseUserRepository(client),
  ));
}

/// Shown when the app is started without the backend settings.
class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Backend settings are missing.\n\nRun the app with\n'
                '--dart-define-from-file=config/supabase.json',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
}
