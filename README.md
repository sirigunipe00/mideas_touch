# Midas’s Touch

Flutter app (Bloc/Cubit) for browsing and editing promotional designs. Catalogue data and template pictures come from Supabase. Logos and fonts stay in the app bundle.

```sh
flutter pub get
flutter run --dart-define-from-file=config/supabase.json

flutter build apk --dart-define-from-file=config/supabase.json

```

VS Code's **Midas’s Touch** launch configuration supplies the same file. `config/supabase.json` is git-ignored and holds only the project URL and publishable key. Copy `config/supabase.example.json` for a fresh checkout.

The database definition is `supabase/backend/01_schema.sql`, `supabase/backend/02_seed.sql`, and `supabase/backend/03_razorpay.sql` (coin purchases). Template pictures live in the `app-assets` storage bucket.

### Razorpay (Test mode)

1. Put `RAZORPAY_KEY_ID` (`rzp_test_…`) in `config/supabase.json`.
2. In Supabase → Edge Functions → Secrets, set `RAZORPAY_KEY_ID` and `RAZORPAY_KEY_SECRET`.
3. Run `supabase/backend/03_razorpay.sql` in the SQL Editor.
4. Deploy functions:
   `supabase functions deploy create-razorpay-order` and
   `supabase functions deploy verify-razorpay-payment`.
5. Referrals: run `supabase/backend/11_referrals.sql`. Invite links look like
   `https://mideas-touch.app/invite/<userId>` (also `mideastouch://invite/<userId>`).
   For production HTTPS links, host that domain / App Links. Friend must open the
   link (or custom scheme) so the app stores the referrer, then **register** —
   the referrer gets 1 coin.

```sh
flutter analyze
flutter test
```
