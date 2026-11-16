-- =====================================================================
-- Match payment_orders created_at / updated_at to templates style:
--   text, IST, format YYYY-MM-DD HH24-MI-SS  e.g. 2026-11-13 15-08-19
--
-- Run once in Supabase SQL Editor.
-- =====================================================================
begin;

drop trigger if exists payment_orders_updated on public.payment_orders;

alter table public.payment_orders
  alter column created_at drop default,
  alter column updated_at drop default;

alter table public.payment_orders
  alter column created_at type text
  using to_char(created_at at time zone 'Asia/Kolkata', 'YYYY-MM-DD HH24-MI-SS'),
  alter column updated_at type text
  using to_char(updated_at at time zone 'Asia/Kolkata', 'YYYY-MM-DD HH24-MI-SS');

alter table public.payment_orders
  alter column created_at set default
    to_char((now() at time zone 'Asia/Kolkata'), 'YYYY-MM-DD HH24-MI-SS'),
  alter column updated_at set default
    to_char((now() at time zone 'Asia/Kolkata'), 'YYYY-MM-DD HH24-MI-SS');

-- set_updated_at() writes timestamptz; use a text-friendly trigger instead.
create or replace function public.set_payment_orders_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at :=
    to_char((now() at time zone 'Asia/Kolkata'), 'YYYY-MM-DD HH24-MI-SS');
  return new;
end;
$$;

create trigger payment_orders_updated
  before update on public.payment_orders
  for each row execute function public.set_payment_orders_updated_at();

commit;
