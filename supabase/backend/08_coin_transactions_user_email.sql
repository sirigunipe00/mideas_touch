-- =====================================================================
-- Add user_email on coin_transactions (filled from profiles).
-- Run once in Supabase SQL Editor.
-- =====================================================================
begin;

alter table public.coin_transactions
  add column if not exists user_email text;

-- Backfill existing rows
update public.coin_transactions ct
set user_email = p.email
from public.profiles p
where p.id = ct.user_id
  and (ct.user_email is null or ct.user_email = '');

-- Auto-fill on every new transaction
create or replace function public.set_coin_tx_user_email()
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

drop trigger if exists coin_transactions_user_email on public.coin_transactions;
create trigger coin_transactions_user_email
  before insert on public.coin_transactions
  for each row execute function public.set_coin_tx_user_email();

commit;
