# Midas’s Touch

Flutter/Dart mobile implementation of the supplied HTML artifact with Bloc/Cubit, GetIt, Freezed, Supabase Auth, PostgreSQL and Storage.

Run using the existing project's local configuration:

```sh
flutter pub get
flutter run --dart-define-from-file=config/supabase.json
```

VS Code's **Midas’s Touch** launch configuration supplies the same file. `config/supabase.json` is ignored by Git; it contains only the API URL and publishable key. Create it from `config/supabase.example.json` for a fresh checkout.

**Inspect the existing Supabase database before applying SQL.** [Inspection queries](docs/database-inspection.sql) and a guarded baseline/seed in [supabase_schema.sql](supabase_schema.sql) are prepared. No remote changes have been applied. A management connection is required to inspect and adapt the migration to existing tables.

[Implementation, setup and remaining integration work](docs/IMPLEMENTATION.md) · [Original artifact](docs/artifact-reference.html) · [Extracted original data](supabase/seed/artifact.json)

```sh
flutter analyze
flutter test
flutter build apk --debug --dart-define-from-file=config/supabase.json
```

The tests cover original-data serialization, immutable models, error behavior, editor history/persistence, and phone widths of 320, 390 and 430 pixels. The source's payments and social rewards are demos; server-side demo crediting is disabled by default.
