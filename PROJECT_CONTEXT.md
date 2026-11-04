# PROJECT_CONTEXT — Midas's Touch (Flutter + Supabase)

Last updated: 2026-11-03. Read this first when resuming work.

## 1. What the app is
A promotional-design studio. Users browse templates, pay 1 coin to unlock/customise one,
edit it on a canvas, then export a JPG or share it. **UI, colours, fonts, text and flow
must not change.**
Creator mode / Studio publishing is **on hold** (still local only; not backed by the DB).

## 2. Status
| Area | State |
|---|---|
| Flutter UI | Done, unchanged |
| Data layer (repositories + Supabase implementations) | Written, `dart analyze lib test` clean |
| Tests (fake in-memory backend) | 30 pass (`flutter test`) |
| SQL (`supabase/backend/*.sql`) | Written, **never run** (no DB access from the dev sandbox) |
| Live Supabase project | **Not touched / never contacted**; nothing verified on a device |

## 3. What lives where
- Dynamic data: Supabase tables (categories, fonts, backgrounds, stock_assets, coin_packs,
  earn_tasks, banners, templates + template_elements). Template pictures: Storage bucket
  `app-assets/templates/diwali-greeting-NN.jpg` (public). Pictures are downloaded into
  memory only (no disk cache).
- Per-user data: `profiles` (trigger-created), `user_designs`, `unlocked_templates`,
  `coin_transactions`, `user_tasks`. RLS on all tables. Coins/role/premium can only change
  through SECURITY DEFINER RPCs (`unlock_template`, `claim_task`, `send_coins`,
  `buy_coin_pack`). After every RPC the app re-fetches the user snapshot.
- Local only: logos, fonts, translations, theme/language choice, Supabase auth token
  (handled by supabase_flutter).
- Old `lib/data/catalog.dart` (dummy data) was deleted.

## 4. Code map
- `lib/data/repositories.dart` — abstract `CatalogRepository`, `AuthRepository`,
  `UserRepository`, `AppException`.
- `lib/data/supabase/` — `supabase_config.dart` (url/publishable key from
  `--dart-define-from-file=config/supabase.json`), `supabase_errors.dart`
  (`logBackendError`, `friendlyError`), and the three Supabase repositories.
- `lib/data/mappers.dart` — DB row <-> models. `lib/models/catalog_models.dart` — catalogue
  models.
- `lib/state/catalog_cubit.dart` — loading/ready/error + progressive picture download.
  `session_cubit.dart` — user snapshot. `app/app_controller.dart` — facade
  (`start`, `submitAuth`, `logout`, `earn`, `buy`, `sendCoins`, `unlock`, `save`, …).
- `lib/main.dart` — initialises Supabase; shows a "config missing" screen without keys.
- Tests: `test/fakes.dart` (in-memory backend following the SQL rules),
  `test/state_test.dart`, `test/widget_test.dart`.

## 5. Setup runbook (already applied to the live project)
1. SQL Editor: `supabase/backend/01_schema.sql`, then `02_seed.sql`.
   `00_reset_legacy.sql` drops tables; run it only to wipe and start over.
2. Template pictures are in the `app-assets` bucket under `templates/`. The app
   downloads them; they are not stored in the project.
3. Authentication → Sign In / Providers → Email: **Confirm email** off, minimum
   password length **8**.
4. `config/supabase.json` (gitignored) holds `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`.
   `.vscode/launch.json` passes it. CLI:
   `flutter run --dart-define-from-file=config/supabase.json`.

## 6. Known caveats
1. Diwali templates are flat pictures with the text baked in: they open in the editor with
   no editable layers (add text/shapes on top). `template_elements` is supported for future
   templates.
2. New users start with an empty My Designs.
3. Creator mode, studio publishing and share links are local only (on hold).
4. `buy_coin_pack` is a demo (`app_settings.demo_payments_enabled = true`): any signed-in
   user can mint coins. Set it to `false` before launch.
5. All 28 pictures decoded at 1024² use roughly 117 MB of memory.
6. Android `INTERNET` permission is in the main manifest. macOS builds would additionally need
   the `com.apple.security.network.client` entitlement.
7. The old local catalogue, the first SQL draft, and the duplicate template
   pictures were removed. `supabase/backend/` is the schema that matches the database.

## 7. Commands
```
export FLUTTER_ROOT=/Users/premsaim/Easycloud/flutter   # dev sandbox only
dart analyze lib test
flutter test
flutter run --dart-define-from-file=config/supabase.json
```
