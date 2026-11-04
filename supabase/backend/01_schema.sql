-- =====================================================================
-- Midas's Touch — STEP 1: schema, security (RLS) and server-side actions.
--
-- Run in the Supabase SQL editor (or `psql`) AFTER 00_reset_legacy.sql when the
-- project still contains tables from earlier attempts.
--
-- Rules this schema enforces
--   * Passwords live only in Supabase Auth. public.profiles holds the profile.
--   * A signed-in user can read ONLY their own profile / wallet / designs.
--   * Clients can never write coins, role or premium. Coins change only inside
--     the SECURITY DEFINER functions at the bottom (one transaction each).
--   * Catalogue tables (categories, templates, ...) are read-only for the app.
--     They are filled from 02_seed.sql / the dashboard.
--   * "Creator" features are ON HOLD: profiles.role exists, nothing else yet.
-- =====================================================================
begin;

-- ---------------------------------------------------------------------
-- 0. Helpers
-- ---------------------------------------------------------------------
create function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

-- ---------------------------------------------------------------------
-- 1. Accounts
-- ---------------------------------------------------------------------
create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  full_name   text not null check (char_length(btrim(full_name)) between 1 and 60),
  email       text not null,
  role        text not null default 'customer' check (role in ('customer', 'creator')),
  coins       integer not null default 0 check (coins >= 0),
  is_premium  boolean not null default false,   -- premium = no watermark on exports
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create unique index profiles_email_key on public.profiles (lower(email));
create trigger profiles_updated before update on public.profiles
  for each row execute function public.set_updated_at();

-- Creates the profile the moment Supabase Auth creates the login.
-- The app passes the name as `data: {'full_name': ...}` in auth.signUp().
create function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  nm text := btrim(coalesce(new.raw_user_meta_data ->> 'full_name', ''));
begin
  if nm = '' then nm := split_part(coalesce(new.email, ''), '@', 1); end if;
  if nm = '' then nm := 'User'; end if;
  insert into public.profiles (id, full_name, email)
  values (new.id, left(nm, 60), coalesce(new.email, ''));
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------
-- 2. Catalogue (read-only for the app)
-- ---------------------------------------------------------------------
create table public.categories (
  id         bigint generated always as identity primary key,
  name       text not null unique,
  sort_order integer not null default 0,
  is_active  boolean not null default true
);

create table public.fonts (                 -- must match a font bundled in assets/fonts
  id         bigint generated always as identity primary key,
  family     text not null unique,
  sort_order integer not null default 0,
  is_active  boolean not null default true
);

create table public.backgrounds (           -- editor "Background" gradients
  id         bigint generated always as identity primary key,
  name       text not null default '',
  color_from text not null check (color_from ~ '^#[0-9a-fA-F]{6}$'),
  color_to   text not null check (color_to   ~ '^#[0-9a-fA-F]{6}$'),
  sort_order integer not null default 0,
  is_active  boolean not null default true
);

create table public.stock_assets (          -- editor "Images" tab
  id         bigint generated always as identity primary key,
  emoji      text not null,
  keywords   text not null default '',
  sort_order integer not null default 0,
  is_active  boolean not null default true
);

create table public.coin_packs (
  id          bigint generated always as identity primary key,
  name        text not null,
  price_inr   integer not null check (price_inr > 0),
  coins       integer not null check (coins > 0),
  bonus_coins integer not null default 0 check (bonus_coins >= 0),
  is_popular  boolean not null default false,
  sort_order  integer not null default 0,
  is_active   boolean not null default true
);

create table public.earn_tasks (            -- "Earn coins" rows on the wallet screen
  key           text primary key,           -- 'follow' | 'refer' | 'tag'
  icon          text not null,
  title         text not null,
  description   text not null,
  button_label  text not null default '+1 🪙',
  history_label text not null,              -- text written to the coin history
  reward_coins  integer not null default 1 check (reward_coins > 0),
  sort_order    integer not null default 0,
  is_active     boolean not null default true
);

create table public.banners (               -- home screen hero slides
  id              bigint generated always as identity primary key,
  tag             text not null,
  title           text not null,
  body            text not null,
  button_label    text not null,
  tag_hi          text,
  title_hi        text,
  body_hi         text,
  button_label_hi text,
  action          text not null check (action in ('startCreating', 'earnCoins', 'seePacks', 'explore')),
  color_from      text not null check (color_from ~ '^#[0-9a-fA-F]{6}$'),
  color_to        text not null check (color_to   ~ '^#[0-9a-fA-F]{6}$'),
  is_dark         boolean not null default false,
  sort_order      integer not null default 0,
  is_active       boolean not null default true
);

create table public.app_settings (          -- small switches, e.g. demo_payments_enabled
  key   text primary key,
  value jsonb not null
);

-- A template. Its picture lives in Storage (bucket app-assets); the gradient is
-- only the placeholder shown while the picture downloads.
create table public.templates (
  id                    bigint generated always as identity primary key,
  name                  text not null check (char_length(btrim(name)) > 0),
  category_id           bigint references public.categories (id) on delete set null,
  description           text not null default '',
  bg_from               text not null check (bg_from ~ '^#[0-9a-fA-F]{6}$'),
  bg_to                 text not null check (bg_to   ~ '^#[0-9a-fA-F]{6}$'),
  background_image_path text,                          -- e.g. templates/diwali-greeting-01.jpg
  author_name           text not null default 'Studio Team',
  creator_id            uuid references public.profiles (id) on delete set null,   -- creators: on hold
  is_premium            boolean not null default false,
  price_inr             integer not null default 0 check (price_inr >= 0),
  status                text not null default 'published' check (status in ('draft', 'published', 'archived')),
  sort_order            integer not null default 0,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);
create index templates_category_idx on public.templates (category_id);
create index templates_status_idx   on public.templates (status, sort_order);
create trigger templates_updated before update on public.templates
  for each row execute function public.set_updated_at();

-- Optional editable layers on top of the picture. z_index 0 is drawn first.
create table public.template_elements (
  id           bigint generated always as identity primary key,
  template_id  bigint not null references public.templates (id) on delete cascade,
  z_index      integer not null,
  kind         text not null check (kind in ('text', 'shape', 'image')),
  x            numeric not null,                 -- % of the square canvas
  y            numeric not null,
  w            numeric not null,
  h            numeric,                          -- shapes only
  rotation     numeric not null default 0,
  text_content text,
  font_family  text,
  font_size    numeric,                          -- on a 400px canvas
  color        text,
  bold         boolean not null default false,
  italic       boolean not null default false,
  underline    boolean not null default false,
  text_align   text check (text_align in ('left', 'center', 'right')),
  fill         text,                             -- '#rrggbb'
  shape_style  text check (shape_style in ('rect', 'ellipse', 'pill')),
  emoji        text,
  is_photo     boolean not null default false,
  unique (template_id, z_index),
  check (kind <> 'text'  or (text_content is not null and font_size is not null)),
  check (kind <> 'shape' or (fill is not null and h is not null)),
  check (kind <> 'image' or emoji is not null)
);

-- ---------------------------------------------------------------------
-- 3. Per-user data
-- ---------------------------------------------------------------------
-- A saved design ("My Designs"). The id is generated by the app, so it is
-- unique per user, not globally.
create table public.user_designs (
  user_id               uuid   not null references public.profiles (id) on delete cascade,
  id                    bigint not null,
  source_template_id    bigint references public.templates (id) on delete set null,
  name                  text   not null check (char_length(btrim(name)) > 0),
  category              text   not null default '',
  description           text   not null default '',
  bg_from               text   not null check (bg_from ~ '^#[0-9a-fA-F]{6}$'),
  bg_to                 text   not null check (bg_to   ~ '^#[0-9a-fA-F]{6}$'),
  background_image_path text,                          -- a path in bucket app-assets
  elements              jsonb  not null default '[]'::jsonb check (jsonb_typeof(elements) = 'array'),
  status                text   not null default 'Draft' check (status in ('Draft', 'Completed')),
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),   -- drives "Last edited"
  primary key (user_id, id)
);
create index user_designs_recent_idx on public.user_designs (user_id, updated_at desc);
create trigger user_designs_updated before update on public.user_designs
  for each row execute function public.set_updated_at();

create table public.unlocked_templates (
  user_id     uuid   not null references public.profiles (id) on delete cascade,
  template_id bigint not null references public.templates (id) on delete cascade,
  unlocked_at timestamptz not null default now(),
  primary key (user_id, template_id)
);

create table public.coin_transactions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles (id) on delete cascade,
  amount      integer not null check (amount <> 0),
  label       text not null,
  kind        text not null check (kind in ('earn', 'purchase', 'unlock', 'transfer_in', 'transfer_out')),
  template_id bigint references public.templates (id) on delete set null,
  created_at  timestamptz not null default now()
);
create index coin_transactions_user_idx on public.coin_transactions (user_id, created_at desc);

create table public.user_tasks (            -- completed "Earn coins" tasks
  user_id      uuid not null references public.profiles (id) on delete cascade,
  task_key     text not null references public.earn_tasks (key) on delete cascade,
  completed_at timestamptz not null default now(),
  primary key (user_id, task_key)
);

-- ---------------------------------------------------------------------
-- 4. Row Level Security
-- ---------------------------------------------------------------------
alter table public.profiles           enable row level security;
alter table public.categories         enable row level security;
alter table public.fonts              enable row level security;
alter table public.backgrounds        enable row level security;
alter table public.stock_assets       enable row level security;
alter table public.coin_packs         enable row level security;
alter table public.earn_tasks         enable row level security;
alter table public.banners            enable row level security;
alter table public.app_settings       enable row level security;
alter table public.templates          enable row level security;
alter table public.template_elements  enable row level security;
alter table public.user_designs       enable row level security;
alter table public.unlocked_templates enable row level security;
alter table public.coin_transactions  enable row level security;
alter table public.user_tasks         enable row level security;

-- Start from nothing, then grant only what the app needs.
revoke all on all tables in schema public from anon, authenticated;

-- Catalogue: anyone (guests included) may read; nobody may write from the app.
grant select on public.categories, public.fonts, public.backgrounds,
  public.stock_assets, public.coin_packs, public.earn_tasks, public.banners,
  public.templates, public.template_elements
  to anon, authenticated;

create policy categories_read   on public.categories   for select using (is_active);
create policy fonts_read        on public.fonts        for select using (is_active);
create policy backgrounds_read  on public.backgrounds  for select using (is_active);
create policy stock_assets_read on public.stock_assets for select using (is_active);
create policy coin_packs_read   on public.coin_packs   for select using (is_active);
create policy earn_tasks_read   on public.earn_tasks   for select using (is_active);
create policy banners_read      on public.banners      for select using (is_active);
create policy templates_read    on public.templates    for select using (status = 'published');
create policy template_elements_read on public.template_elements for select
  using (exists (select 1 from public.templates t
                 where t.id = template_id and t.status = 'published'));
-- app_settings has no policy and no grant: only the server functions read it.

-- Profile: read your own row. Nothing is writable by the app (coins, role and
-- premium can never be edited by a client, and the name is set at sign-up).
grant select on public.profiles to authenticated;
create policy profiles_select_own on public.profiles for select to authenticated
  using (id = auth.uid());

-- Saved designs: full control over your own rows only.
grant select, insert, update, delete on public.user_designs to authenticated;
create policy user_designs_own on public.user_designs for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Wallet data: readable by its owner, written only by the functions below.
grant select on public.unlocked_templates, public.coin_transactions, public.user_tasks
  to authenticated;
create policy unlocked_own   on public.unlocked_templates for select to authenticated using (user_id = auth.uid());
create policy coin_tx_own    on public.coin_transactions  for select to authenticated using (user_id = auth.uid());
create policy user_tasks_own on public.user_tasks         for select to authenticated using (user_id = auth.uid());

-- ---------------------------------------------------------------------
-- 5. Server-side actions (the ONLY way coins ever change)
-- ---------------------------------------------------------------------

-- Unlock a template for 1 coin. Returns false when the user cannot afford it.
-- Unlocking twice is free (returns true).
create function public.unlock_template(p_template_id bigint)
returns boolean language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  t  public.templates;
  p  public.profiles;
begin
  if me is null then raise exception 'Sign in required'; end if;
  select * into t from public.templates where id = p_template_id and status = 'published';
  if not found then raise exception 'Design unavailable'; end if;
  if exists (select 1 from public.unlocked_templates where user_id = me and template_id = t.id) then
    return true;
  end if;
  select * into p from public.profiles where id = me for update;
  if p.coins < 1 then return false; end if;
  update public.profiles set coins = coins - 1 where id = me;
  insert into public.unlocked_templates (user_id, template_id) values (me, t.id);
  insert into public.coin_transactions (user_id, amount, label, kind, template_id)
    values (me, -1, 'Unlocked ' || t.name, 'unlock', t.id);
  return true;
end $$;

-- Complete an "Earn coins" task once. Returns true when coins were awarded.
create function public.claim_task(p_key text)
returns boolean language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  k  public.earn_tasks;
begin
  if me is null then raise exception 'Sign in required'; end if;
  select * into k from public.earn_tasks where key = p_key and is_active;
  if not found then raise exception 'Invalid task'; end if;
  insert into public.user_tasks (user_id, task_key) values (me, p_key)
    on conflict do nothing;
  if not found then return false; end if;          -- already completed
  update public.profiles set coins = coins + k.reward_coins where id = me;
  insert into public.coin_transactions (user_id, amount, label, kind)
    values (me, k.reward_coins, k.history_label, 'earn');
  return true;
end $$;

-- Send coins to another user, identified by their e-mail address.
create function public.send_coins(p_recipient text, p_amount integer)
returns void language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  r  uuid;
begin
  if me is null then raise exception 'Sign in required'; end if;
  if p_amount is null or p_amount < 1 then raise exception 'Enter number of coins'; end if;
  select id into r from public.profiles where lower(email) = lower(btrim(p_recipient));
  if r is null or r = me then raise exception 'Recipient not found'; end if;
  perform 1 from public.profiles where id in (me, r) order by id for update;
  if (select coins from public.profiles where id = me) < p_amount then
    raise exception 'Not enough coins';
  end if;
  update public.profiles set coins = coins - p_amount where id = me;
  update public.profiles set coins = coins + p_amount where id = r;
  insert into public.coin_transactions (user_id, amount, label, kind) values
    (me, -p_amount, 'Sent to ' || btrim(p_recipient), 'transfer_out'),
    (r,   p_amount, 'Received coins',                 'transfer_in');
end $$;

-- PLACEHOLDER PAYMENT. The app's "Buy" button is a demo today ("Payment
-- successful (demo)"). It only works while app_settings.demo_payments_enabled
-- is true. Replace with a real payment webhook and switch the flag off before
-- launch, otherwise any signed-in user can mint coins.
create function public.buy_coin_pack(p_pack_id bigint)
returns void language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  k  public.coin_packs;
begin
  if me is null then raise exception 'Sign in required'; end if;
  if coalesce((select value #>> '{}' from public.app_settings where key = 'demo_payments_enabled'), 'false') <> 'true' then
    raise exception 'Payments are not enabled';
  end if;
  select * into k from public.coin_packs where id = p_pack_id and is_active;
  if not found then raise exception 'Invalid pack'; end if;
  update public.profiles set coins = coins + k.coins + k.bonus_coins where id = me;
  insert into public.coin_transactions (user_id, amount, label, kind)
    values (me, k.coins + k.bonus_coins, 'Bought ₹' || k.price_inr || ' pack', 'purchase');
end $$;

-- Supabase grants EXECUTE to anon/authenticated by default; allow signed-in only.
revoke all on function public.unlock_template(bigint), public.claim_task(text),
  public.send_coins(text, integer), public.buy_coin_pack(bigint) from public, anon;
grant execute on function public.unlock_template(bigint), public.claim_task(text),
  public.send_coins(text, integer), public.buy_coin_pack(bigint) to authenticated;

-- ---------------------------------------------------------------------
-- 6. Storage
--   app-assets : PUBLIC read. Template pictures live here (templates/...).
--                Written only with the service-role key (tool/seed_storage.py)
--                or from the dashboard; the app never uploads.
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('app-assets', 'app-assets', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create policy app_assets_read on storage.objects for select
  using (bucket_id = 'app-assets');

commit;
