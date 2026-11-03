# Midas’s Touch implementation

The HTML reference is preserved in `docs/artifact-reference.html`. The JSON extracted from its declarative constants is `supabase/seed/artifact.json`. Flutter does not bundle that catalog: templates, banners, categories, stock assets, gradients, coin packs and prototype studio statistics load from Supabase. Original embedded logos and the seven original font families are bundled to keep initial rendering reliable. Once the catalog loads, logo paths come from Supabase and resolve to Storage. The inline gold coin is drawn from the original SVG coordinates. The asset upload script also prepares the same logos for Supabase Storage; template imagery in the source is emoji artwork rather than photo files.

## Existing project — inspect before applying

The supplied project reference is `ctabyiufqvzxcggmhiix`. The app's API URL is `https://ctabyiufqvzxcggmhiix.supabase.co`, not the dashboard URL. Local configuration is in ignored `config/supabase.json`; VS Code launch configuration uses it. The publishable key is the only application key required.

1. Connect Supabase management access and run `docs/database-inspection.sql` first. The publishable key cannot run DDL or inspect all schemas/policies. Direct TLS connectivity checks from this environment failed; no remote schema or data changes have been applied.
2. Compare the inspected schema, policies, functions and Storage buckets with the prepared baseline. `supabase_schema.sql` deliberately aborts if any application table already exists. Adapt an additive migration to the inspected project before applying it. Do not drop, replace or seed over existing records. Catalog inserts use `ON CONFLICT DO NOTHING`; collisions must be reviewed rather than overwritten.
3. For a project without colliding application tables, the baseline and original seed are combined in `supabase_schema.sql`. The migration and seed also exist separately under `supabase/`.
4. Upload the original logos using `tool/upload_artifact_assets.py` with `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` supplied locally through environment variables. It skips existing paths and never enables upload upserts. Do not send a service key to the mobile app or commit it.
5. Create a test account through Supabase Auth. Original saved-design examples are copied to that account by the registration trigger. Existing accounts are not modified automatically. Email confirmation, when enabled, requires confirming the message and then logging in. To use Creator Studio, an account must have `profiles.role = 'creator'`, assigned through an inspected, authorized admin operation.

```sh
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run --dart-define-from-file=config/supabase.json
flutter test
flutter analyze
```

To reproduce the original seed:

```sh
node tool/extract_artifact.cjs '/path/to/Midas’s Touch (2).html'
python3 tool/prepare_seed.py
```

## Behavior and remaining integration verification

- All customization requires login and a one-coin unlock, as in the artifact, including templates with the source's legacy free/premium flags. Unlocks and sends are transactional database functions; balances cannot be edited directly by clients.
- The source labels payments/social actions as simulations. The database ships with those demo credits disabled. An administrator can enable `demo_settings.enabled` for artifact testing after inspection/approval; actual payment processing and verified social rewards need provider integrations.
- Native JPG export renders at 1080×1080 with adjustable JPEG quality and source-style watermarking. It saves in app documents and opens the native share sheet, where the user chooses Files/gallery/another app.
- Shared links point to real uploaded JPGs in Supabase Storage. An in-app shared-design preview and expired state are included. A custom-domain interactive shared webpage and automatic expiry/deletion of public image objects are not deployed.
- Original fonts are bundled. Unicode emoji appearance still follows each OS's emoji font, as the HTML does.
- Android APK and iOS Simulator compilation have passed. Responsive widget tests and a browser-reference home comparison have been run. Device runtime testing, complete screen-by-screen visual comparison, database/RLS verification and live Auth/Storage round trips remain necessary before claiming exact visual parity or production readiness.
