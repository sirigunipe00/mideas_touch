# Midas’s Touch

Flutter app (Bloc/Cubit) for browsing and editing promotional designs. Catalogue data and template pictures come from Supabase. Logos and fonts stay in the app bundle.

```sh
flutter pub get
flutter run --dart-define-from-file=config/supabase.json
```

VS Code's **Midas’s Touch** launch configuration supplies the same file. `config/supabase.json` is git-ignored and holds only the project URL and publishable key. Copy `config/supabase.example.json` for a fresh checkout.

The database definition is `supabase/backend/01_schema.sql` and `supabase/backend/02_seed.sql`. Template pictures live in the `app-assets` storage bucket.

```sh
flutter analyze
flutter test
```
