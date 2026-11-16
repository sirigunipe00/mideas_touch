-- =====================================================================
-- Convert EVERY timestamptz column in schema public → IST text
-- Format: 2026-11-13 15-08-19  (same as templates Table Editor)
--
-- - One script for all tables (no per-table manual updates)
-- - Skips columns already text
-- - Does NOT touch auth.* (Supabase-managed)
-- - Safe to re-run
--
-- Run once in Supabase SQL Editor.
-- =====================================================================
begin;

create or replace function public.ist_now_text()
returns text
language sql
stable
as $$
  select to_char((now() at time zone 'Asia/Kolkata'), 'YYYY-MM-DD HH24-MI-SS');
$$;

-- Discover and convert all timestamptz columns in public.
do $$
declare
  r record;
begin
  for r in
    select c.table_name, c.column_name
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name not like 'pg_%'
      and c.data_type = 'timestamp with time zone'
    order by c.table_name, c.column_name
  loop
    execute format(
      'alter table public.%I alter column %I drop default',
      r.table_name, r.column_name
    );
    execute format(
      'alter table public.%I alter column %I type text using to_char(%I at time zone %L, %L)',
      r.table_name, r.column_name, r.column_name,
      'Asia/Kolkata', 'YYYY-MM-DD HH24-MI-SS'
    );
    execute format(
      'alter table public.%I alter column %I set default public.ist_now_text()',
      r.table_name, r.column_name
    );
    raise notice 'converted %.%', r.table_name, r.column_name;
  end loop;
end $$;

-- Shared updated_at trigger writes IST text.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = public.ist_now_text();
  return new;
end;
$$;

-- payment_orders: use shared trigger if that table exists
do $$
begin
  if to_regclass('public.payment_orders') is not null then
    drop trigger if exists payment_orders_updated on public.payment_orders;
    create trigger payment_orders_updated
      before update on public.payment_orders
      for each row execute function public.set_updated_at();
  end if;
end $$;

drop function if exists public.set_payment_orders_updated_at();

commit;

-- Optional check: should return 0 rows if everything is converted
-- select table_name, column_name, data_type
-- from information_schema.columns
-- where table_schema = 'public'
--   and data_type = 'timestamp with time zone';
