-- =====================================================================
-- Midas's Touch — PROPOSED Supabase schema (Phase 1: for review only)
--
-- STATUS: NOT EXECUTED. Nothing in this file has been run against any
-- Supabase project. It will only be applied after you approve it.
-- It has not been syntax-checked against a live Postgres either; that
-- happens on a scratch run once you approve.
--
-- Conventions
--   * Every user-owned row points at public.profiles(id) = auth.users(id).
--   * Passwords are never stored here; Supabase Auth owns them.
--   * Clients can never change coins / role / premium directly: those
--     columns are not writable by the `authenticated` role and are only
--     changed by SECURITY DEFINER functions below.
-- =====================================================================
begin;

-- ---------------------------------------------------------------------
-- 0. Helpers
-- ---------------------------------------------------------------------
create or replace function public.set_updated_at()
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
  full_name   text not null check (char_length(btrim(full_name)) between 2 and 60),
  email       text not null check (email ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
  phone       text check (phone is null or phone ~ '^\+?[0-9]{7,15}$'),
  role        text not null default 'customer' check (role in ('customer', 'creator')),
  coins       integer not null default 0 check (coins >= 0),
  is_premium  boolean not null default false,
  language    text not null default 'en' check (language in ('en', 'hi')),
  theme_mode  text not null default 'system' check (theme_mode in ('light', 'dark', 'system')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create unique index profiles_email_key on public.profiles (lower(email));
create unique index profiles_phone_key on public.profiles (phone) where phone is not null;
create trigger profiles_updated before update on public.profiles
  for each row execute function public.set_updated_at();

-- Creates the profile row the moment Supabase Auth creates the user.
-- Registration data is passed as `data:` in supabase.auth.signUp(...).
create function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name, email, phone)
  values (
    new.id,
    btrim(coalesce(new.raw_user_meta_data ->> 'full_name', '')),
    new.email,
    nullif(btrim(coalesce(new.raw_user_meta_data ->> 'phone', '')), '')
  );
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

create function public.is_creator()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'creator');
$$;

-- ---------------------------------------------------------------------
-- 2. Public content (read by everyone, written only from the dashboard)
-- ---------------------------------------------------------------------
create table public.categories (
  id         bigint generated always as identity primary key,
  name       text not null unique,
  sort_order integer not null default 0,
  is_active  boolean not null default true
);

create table public.fonts (
  id         bigint generated always as identity primary key,
  family     text not null unique,      -- must match a bundled font family
  sort_order integer not null default 0,
  is_active  boolean not null default true
);

create table public.backgrounds (          -- editor "Background" gradients
  id         bigint generated always as identity primary key,
  name       text not null default '',
  color_from text not null check (color_from ~ '^#[0-9a-fA-F]{6}$'),
  color_to   text not null check (color_to   ~ '^#[0-9a-fA-F]{6}$'),
  sort_order integer not null default 0,
  is_active  boolean not null default true
);

create table public.stock_assets (         -- editor "Images" tab
  id         bigint generated always as identity primary key,
  emoji      text,                         -- current artwork (an emoji)
  image_path text,                         -- optional: file in bucket app-assets
  keywords   text not null default '',
  sort_order integer not null default 0,
  is_active  boolean not null default true,
  check (emoji is not null or image_path is not null)
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

create table public.earn_tasks (
  key          text primary key,           -- 'follow' | 'refer' | 'tag'
  icon         text not null,
  title        text not null,
  description  text not null,
  button_label text not null default '+1 🪙',
  reward_coins integer not null default 1 check (reward_coins > 0),
  sort_order   integer not null default 0,
  is_active    boolean not null default true
);

create table public.banners (
  id           bigint generated always as identity primary key,
  tag          text not null,
  title        text not null,
  subtitle     text not null,
  button_label text not null,
  action       text not null check (action in ('startCreating', 'earnCoins', 'seePacks', 'explore')),
  color_from   text not null check (color_from ~ '^#[0-9a-fA-F]{6}$'),
  color_to     text not null check (color_to   ~ '^#[0-9a-fA-F]{6}$'),
  is_dark      boolean not null default false,
  sort_order   integer not null default 0,
  is_active    boolean not null default true
);

-- Single-row-per-key settings: invite message, share base URL, watermark text…
create table public.app_settings (
  key   text primary key,
  value jsonb not null
);

-- UI strings (English / Hindi). Optional: see "decisions" in the plan.
create table public.app_strings (
  lang  text not null check (lang in ('en', 'hi')),
  key   text not null,
  value text not null,
  primary key (lang, key)
);

-- ---------------------------------------------------------------------
-- 3. Templates
-- ---------------------------------------------------------------------
create table public.templates (
  id                    bigint generated always as identity primary key,
  name                  text not null check (char_length(btrim(name)) > 0),
  category_id           bigint references public.categories (id) on delete set null,
  description           text not null default '',
  bg_from               text not null check (bg_from ~ '^#[0-9a-fA-F]{6}$'),
  bg_to                 text not null check (bg_to   ~ '^#[0-9a-fA-F]{6}$'),
  background_image_path text,                      -- bucket app-assets / creator-assets
  author_name           text not null default 'Studio Team',
  creator_id            uuid references public.profiles (id) on delete set null,
  is_premium            boolean not null default false,   -- "👑 Premium" badge
  coin_cost             integer not null default 1 check (coin_cost >= 0),
  status                text not null default 'published' check (status in ('draft', 'published', 'archived')),
  sort_order            integer not null default 0,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);
create index templates_category_idx on public.templates (category_id);
create index templates_status_idx   on public.templates (status, sort_order);
create index templates_creator_idx  on public.templates (creator_id);
create trigger templates_updated before update on public.templates
  for each row execute function public.set_updated_at();

-- One row per layer. z_index 0 is drawn first (bottom).
create table public.template_elements (
  id           bigint generated always as identity primary key,
  template_id  bigint not null references public.templates (id) on delete cascade,
  z_index      integer not null,
  kind         text not null check (kind in ('text', 'shape', 'image')),
  x            numeric not null,                -- % of canvas
  y            numeric not null,
  w            numeric not null,
  h            numeric,                         -- shapes only
  rotation     numeric not null default 0,
  -- text
  text_content text,
  font_family  text,
  font_size    numeric,                         -- on a 400px canvas
  color        text,
  bold         boolean not null default false,
  italic       boolean not null default false,
  underline    boolean not null default false,
  text_align   text check (text_align in ('left', 'center', 'right')),
  -- shape
  fill         text,                            -- '#rrggbb' or 'rgba(r,g,b,a)'
  shape_style  text check (shape_style in ('rect', 'ellipse', 'pill')),
  -- image
  emoji        text,
  image_path   text,
  is_photo     boolean not null default false,  -- shows "Remove Background"
  unique (template_id, z_index),
  check (kind <> 'text'  or (text_content is not null and font_size is not null)),
  check (kind <> 'shape' or (fill is not null and h is not null)),
  check (kind <> 'image' or (emoji is not null or image_path is not null))
);
create index template_elements_template_idx on public.template_elements (template_id, z_index);

-- Home sections ("Popular", "Trending", "Recently Added").
create table public.home_sections (
  key        text primary key,
  title_en   text not null,
  title_hi   text not null,
  source     text not null default 'manual' check (source in ('manual', 'most_used', 'newest')),
  sort_order integer not null default 0,
  is_active  boolean not null default true
);
create table public.home_section_items (
  section_key text not null references public.home_sections (key) on delete cascade,
  template_id bigint not null references public.templates (id) on delete cascade,
  sort_order  integer not null default 0,
  primary key (section_key, template_id)
);

-- ---------------------------------------------------------------------
-- 4. Per-user data
-- ---------------------------------------------------------------------
-- A user's saved design. Elements are one jsonb document because the app
-- writes them atomically and nobody edits them by hand.
create table public.user_designs (
  id                    uuid primary key default gen_random_uuid(),
  user_id               uuid not null references public.profiles (id) on delete cascade,
  source_template_id    bigint references public.templates (id) on delete set null,
  name                  text not null check (char_length(btrim(name)) > 0),
  category_id           bigint references public.categories (id) on delete set null,
  description           text not null default '',
  bg_from               text not null check (bg_from ~ '^#[0-9a-fA-F]{6}$'),
  bg_to                 text not null check (bg_to   ~ '^#[0-9a-fA-F]{6}$'),
  background_image_path text,                        -- bucket user-photos
  elements              jsonb not null default '[]'::jsonb check (jsonb_typeof(elements) = 'array'),
  status                text not null default 'Draft' check (status in ('Draft', 'Completed')),
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()   -- drives "Last edited"
);
create index user_designs_user_idx on public.user_designs (user_id, updated_at desc);
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
  kind        text not null check (kind in ('earn', 'purchase', 'unlock', 'transfer_in', 'transfer_out', 'adjustment')),
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

create table public.template_uses (         -- real numbers for the creator dashboard
  id          bigint generated always as identity primary key,
  template_id bigint not null references public.templates (id) on delete cascade,
  user_id     uuid   not null references public.profiles (id) on delete cascade,
  used_at     timestamptz not null default now()
);
create index template_uses_template_idx on public.template_uses (template_id, used_at desc);

-- Public share links (what a recipient sees). A snapshot, so later edits
-- by the owner do not change an already-shared link.
create table public.shared_designs (
  token      text primary key default replace(gen_random_uuid()::text, '-', ''),
  owner_id   uuid not null references public.profiles (id) on delete cascade,
  design_id  uuid references public.user_designs (id) on delete set null,
  snapshot   jsonb not null,
  expires_at timestamptz not null default now() + interval '30 days',
  created_at timestamptz not null default now()
);
create index shared_designs_owner_idx on public.shared_designs (owner_id);

-- Refer-a-friend. 1 coin is credited to the inviter when the invitee signs up.
create table public.invites (
  code        text primary key default substr(replace(gen_random_uuid()::text, '-', ''), 1, 10),
  inviter_id  uuid not null references public.profiles (id) on delete cascade,
  accepted_by uuid references public.profiles (id) on delete set null,
  accepted_at timestamptz,
  created_at  timestamptz not null default now()
);
create index invites_inviter_idx on public.invites (inviter_id);

-- ---------------------------------------------------------------------
-- 5. Row Level Security
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
alter table public.app_strings        enable row level security;
alter table public.templates          enable row level security;
alter table public.template_elements  enable row level security;
alter table public.home_sections      enable row level security;
alter table public.home_section_items enable row level security;
alter table public.user_designs       enable row level security;
alter table public.unlocked_templates enable row level security;
alter table public.coin_transactions  enable row level security;
alter table public.user_tasks         enable row level security;
alter table public.template_uses      enable row level security;
alter table public.shared_designs     enable row level security;
alter table public.invites            enable row level security;

-- Table privileges: start from nothing, then grant only what is needed.
revoke all on all tables in schema public from anon, authenticated;

-- Public catalogue: anyone (signed in or not) may read active rows.
grant select on public.categories, public.fonts, public.backgrounds,
  public.stock_assets, public.coin_packs, public.earn_tasks, public.banners,
  public.app_settings, public.app_strings, public.home_sections,
  public.home_section_items, public.templates, public.template_elements
  to anon, authenticated;

create policy categories_read   on public.categories   for select using (is_active);
create policy fonts_read        on public.fonts        for select using (is_active);
create policy backgrounds_read  on public.backgrounds  for select using (is_active);
create policy stock_assets_read on public.stock_assets for select using (is_active);
create policy coin_packs_read   on public.coin_packs   for select using (is_active);
create policy earn_tasks_read   on public.earn_tasks   for select using (is_active);
create policy banners_read      on public.banners      for select using (is_active);
create policy app_settings_read on public.app_settings for select using (true);
create policy app_strings_read  on public.app_strings  for select using (true);
create policy home_sections_read      on public.home_sections      for select using (is_active);
create policy home_section_items_read on public.home_section_items for select using (true);

-- Templates: published ones are public; a creator also sees and manages their own.
create policy templates_read on public.templates for select
  using (status = 'published' or creator_id = auth.uid());
create policy template_elements_read on public.template_elements for select
  using (exists (select 1 from public.templates t
                 where t.id = template_id and (t.status = 'published' or t.creator_id = auth.uid())));

grant insert, update, delete on public.templates, public.template_elements to authenticated;
create policy templates_creator_insert on public.templates for insert to authenticated
  with check (public.is_creator() and creator_id = auth.uid());
create policy templates_creator_update on public.templates for update to authenticated
  using (creator_id = auth.uid() and public.is_creator())
  with check (creator_id = auth.uid() and public.is_creator());
create policy templates_creator_delete on public.templates for delete to authenticated
  using (creator_id = auth.uid() and public.is_creator());
create policy template_elements_creator_write on public.template_elements for all to authenticated
  using (exists (select 1 from public.templates t
                 where t.id = template_id and t.creator_id = auth.uid() and public.is_creator()))
  with check (exists (select 1 from public.templates t
                 where t.id = template_id and t.creator_id = auth.uid() and public.is_creator()));

-- Profiles: read and edit only your own row, and only harmless columns.
grant select on public.profiles to authenticated;
grant update (full_name, phone, language, theme_mode) on public.profiles to authenticated;
create policy profiles_select_own on public.profiles for select to authenticated using (id = auth.uid());
create policy profiles_update_own on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- Saved designs: full control over your own rows only.
grant select, insert, update, delete on public.user_designs to authenticated;
create policy user_designs_own on public.user_designs for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Read-only (to the owner) data. Writes happen only inside the functions below.
grant select on public.unlocked_templates, public.coin_transactions,
  public.user_tasks, public.invites to authenticated;
create policy unlocked_own on public.unlocked_templates for select to authenticated using (user_id = auth.uid());
create policy coin_tx_own  on public.coin_transactions  for select to authenticated using (user_id = auth.uid());
create policy user_tasks_own on public.user_tasks       for select to authenticated using (user_id = auth.uid());
create policy invites_own  on public.invites            for select to authenticated using (inviter_id = auth.uid());

-- Creators may read the usage rows of their own templates.
grant select on public.template_uses to authenticated;
create policy template_uses_creator on public.template_uses for select to authenticated
  using (exists (select 1 from public.templates t where t.id = template_id and t.creator_id = auth.uid()));

-- Share links: owners manage their own; the public reads through get_shared_design().
grant select, delete on public.shared_designs to authenticated;
create policy shared_owner_read   on public.shared_designs for select to authenticated using (owner_id = auth.uid());
create policy shared_owner_delete on public.shared_designs for delete to authenticated using (owner_id = auth.uid());

-- ---------------------------------------------------------------------
-- 6. Server-side actions (the only way coins ever change)
-- ---------------------------------------------------------------------
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
  -- creators never pay for their own designs
  if t.creator_id = me then return true; end if;
  if exists (select 1 from public.unlocked_templates where user_id = me and template_id = t.id) then
    return true;
  end if;
  select * into p from public.profiles where id = me for update;
  if p.coins < t.coin_cost then return false; end if;
  update public.profiles set coins = coins - t.coin_cost where id = me;
  insert into public.unlocked_templates (user_id, template_id) values (me, t.id);
  insert into public.coin_transactions (user_id, amount, label, kind, template_id)
    values (me, -t.coin_cost, 'Unlocked ' || t.name, 'unlock', t.id);
  insert into public.template_uses (template_id, user_id) values (t.id, me);
  return true;
end $$;

create function public.claim_task(p_key text)
returns void language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  k  public.earn_tasks;
begin
  if me is null then raise exception 'Sign in required'; end if;
  select * into k from public.earn_tasks where key = p_key and is_active;
  if not found then raise exception 'Invalid task'; end if;
  insert into public.user_tasks (user_id, task_key) values (me, p_key) on conflict do nothing;
  if found then
    update public.profiles set coins = coins + k.reward_coins where id = me;
    insert into public.coin_transactions (user_id, amount, label, kind)
      values (me, k.reward_coins, k.title, 'earn');
  end if;
end $$;

create function public.send_coins(p_recipient text, p_amount integer)
returns void language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  r  uuid;
begin
  if me is null then raise exception 'Sign in required'; end if;
  if p_amount is null or p_amount < 1 then raise exception 'Enter number of coins'; end if;
  select id into r from public.profiles
    where lower(email) = lower(btrim(p_recipient)) or (phone is not null and phone = btrim(p_recipient));
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

-- PLACEHOLDER PAYMENT (the app's "Buy" button is a demo today).
-- Disabled by default; replace with a real payment webhook before launch.
create function public.buy_coin_pack_demo(p_pack_id bigint)
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

create function public.create_share_link(p_design_id uuid)
returns text language plpgsql security definer set search_path = public as $$
declare
  d public.user_designs;
  s text;
begin
  select * into d from public.user_designs where id = p_design_id and user_id = auth.uid();
  if not found then raise exception 'Design not found'; end if;
  insert into public.shared_designs (owner_id, design_id, snapshot)
    values (d.user_id, d.id, to_jsonb(d)) returning token into s;
  return s;
end $$;

create function public.get_shared_design(p_token text)
returns jsonb language sql stable security definer set search_path = public as $$
  select snapshot from public.shared_designs where token = p_token and expires_at > now();
$$;

revoke all on function public.unlock_template(bigint), public.claim_task(text),
  public.send_coins(text, integer), public.buy_coin_pack_demo(bigint),
  public.create_share_link(uuid) from public;
grant execute on function public.unlock_template(bigint), public.claim_task(text),
  public.send_coins(text, integer), public.buy_coin_pack_demo(bigint),
  public.create_share_link(uuid) to authenticated;
grant execute on function public.get_shared_design(text) to anon, authenticated;

-- ---------------------------------------------------------------------
-- 7. Storage
--   app-assets     public read   : banners, template images, stock images
--                                  (written from the dashboard only)
--   creator-assets public read   : images used by a creator's published
--                                  templates; creators write inside {uid}/
--   user-photos    private       : a user's own uploaded photos; {uid}/…
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('app-assets',     'app-assets',     true,  5242880, array['image/jpeg', 'image/png', 'image/webp']),
  ('creator-assets', 'creator-assets', true,  5242880, array['image/jpeg', 'image/png', 'image/webp']),
  ('user-photos',    'user-photos',    false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy app_assets_read on storage.objects for select using (bucket_id = 'app-assets');

create policy creator_assets_read on storage.objects for select using (bucket_id = 'creator-assets');
create policy creator_assets_write on storage.objects for insert to authenticated
  with check (bucket_id = 'creator-assets' and public.is_creator()
              and (storage.foldername(name))[1] = auth.uid()::text);
create policy creator_assets_update on storage.objects for update to authenticated
  using (bucket_id = 'creator-assets' and (storage.foldername(name))[1] = auth.uid()::text);
create policy creator_assets_delete on storage.objects for delete to authenticated
  using (bucket_id = 'creator-assets' and (storage.foldername(name))[1] = auth.uid()::text);

create policy user_photos_select on storage.objects for select to authenticated
  using (bucket_id = 'user-photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy user_photos_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'user-photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy user_photos_update on storage.objects for update to authenticated
  using (bucket_id = 'user-photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy user_photos_delete on storage.objects for delete to authenticated
  using (bucket_id = 'user-photos' and (storage.foldername(name))[1] = auth.uid()::text);

commit;
