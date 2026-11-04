-- =====================================================================
-- Midas's Touch — STEP 0 (optional): remove the objects of earlier attempts.
--
-- !! DESTRUCTIVE !!  Run this ONLY on a development project whose data you do
-- not need.  It drops every table, function, trigger and storage policy that
-- the old experiments and this backend use, so 01_schema.sql can start clean.
-- Rows in auth.users (the login accounts) are NOT touched, but profile rows,
-- coins and saved designs are lost.
--
-- Safe to run when nothing exists yet (everything is `if exists`).
-- =====================================================================

-- Triggers on auth.users written by earlier attempts / this backend
drop trigger if exists artifact_profile      on auth.users;
drop trigger if exists on_auth_user_created  on auth.users;

-- Current backend
drop table if exists public.user_tasks          cascade;
drop table if exists public.coin_transactions   cascade;
drop table if exists public.unlocked_templates  cascade;
drop table if exists public.user_designs        cascade;
drop table if exists public.template_elements   cascade;
drop table if exists public.templates           cascade;
drop table if exists public.banners             cascade;
drop table if exists public.earn_tasks          cascade;
drop table if exists public.coin_packs          cascade;
drop table if exists public.stock_assets        cascade;
drop table if exists public.backgrounds         cascade;
drop table if exists public.fonts               cascade;
drop table if exists public.categories          cascade;
drop table if exists public.app_settings        cascade;
drop table if exists public.profiles            cascade;

-- Earlier experiments
drop table if exists public.shared_designs      cascade;
drop table if exists public.app_content         cascade;
drop table if exists public.demo_settings       cascade;
drop table if exists public.app_strings         cascade;
drop table if exists public.invites             cascade;
drop table if exists public.template_uses       cascade;
drop table if exists public.home_section_items  cascade;
drop table if exists public.home_sections       cascade;

drop function if exists public.handle_new_user()                 cascade;
drop function if exists public.create_artifact_profile()         cascade;
drop function if exists public.set_updated_at()                  cascade;
drop function if exists public.is_creator()                      cascade;
drop function if exists public.unlock_template(bigint)           cascade;
drop function if exists public.unlock_design(bigint)             cascade;
drop function if exists public.claim_task(text)                  cascade;
drop function if exists public.send_coins(text, integer)         cascade;
drop function if exists public.buy_coin_pack(bigint)             cascade;
drop function if exists public.buy_coin_pack_demo(bigint)        cascade;
drop function if exists public.demo_coins(text, integer)         cascade;
drop function if exists public.create_share_link(uuid)           cascade;
drop function if exists public.get_shared_design(text)           cascade;
drop function if exists public.read_shared_design(uuid)          cascade;

-- Storage policies from earlier attempts / this backend (buckets and the files
-- inside them are left alone; remove them from the dashboard if unwanted).
drop policy if exists asset_read           on storage.objects;
drop policy if exists asset_upload         on storage.objects;
drop policy if exists app_assets_read      on storage.objects;
drop policy if exists creator_assets_read  on storage.objects;
drop policy if exists creator_assets_write on storage.objects;
drop policy if exists user_photos_select   on storage.objects;
drop policy if exists user_photos_insert   on storage.objects;
