-- =====================================================================
-- Add user_email on payment_orders (filled from profiles).
-- Run once in Supabase SQL Editor.
-- =====================================================================
begin;

alter table public.payment_orders
  add column if not exists user_email text;

-- Backfill existing rows
update public.payment_orders po
set user_email = p.email
from public.profiles p
where p.id = po.user_id
  and (po.user_email is null or po.user_email = '');

-- Auto-fill on insert / update when email is missing
create or replace function public.set_payment_orders_user_email()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.user_email is null or btrim(new.user_email) = '' then
    select email into new.user_email
    from public.profiles
    where id = new.user_id;
  end if;
  return new;
end;
$$;

drop trigger if exists payment_orders_user_email on public.payment_orders;
create trigger payment_orders_user_email
  before insert or update on public.payment_orders
  for each row execute function public.set_payment_orders_user_email();

commit;
