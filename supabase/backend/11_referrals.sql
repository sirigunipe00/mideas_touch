-- =====================================================================
-- Refer a friend: 1 coin to the referrer when a new user registers via
-- their invite link. Run once in Supabase SQL Editor.
-- =====================================================================
begin;

-- Needed if 09_all_timestamps_ist_text.sql was not run yet.
create or replace function public.ist_now_text()
returns text
language sql
stable
as $$
  select to_char((now() at time zone 'Asia/Kolkata'), 'YYYY-MM-DD HH24-MI-SS');
$$;

create table if not exists public.referrals (
  referred_id  uuid primary key references public.profiles (id) on delete cascade,
  referrer_id  uuid not null references public.profiles (id) on delete cascade,
  created_at   text not null default public.ist_now_text(),
  constraint referrals_no_self check (referred_id <> referrer_id)
);
create index if not exists referrals_referrer_idx
  on public.referrals (referrer_id, created_at desc);

alter table public.referrals enable row level security;
revoke all on public.referrals from anon, authenticated;
grant select on public.referrals to authenticated;

drop policy if exists referrals_read_own on public.referrals;
create policy referrals_read_own on public.referrals
  for select to authenticated
  using (referrer_id = auth.uid() or referred_id = auth.uid());

-- Update earn_tasks copy for refer.
update public.earn_tasks
set description = '1 coin when a friend installs & registers via your link',
    history_label = 'Friend joined with your invite'
where key = 'refer';

-- claim_task must not mint the refer reward directly anymore.
create or replace function public.claim_task(p_key text)
returns boolean language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  k  public.earn_tasks;
begin
  if me is null then raise exception 'Sign in required'; end if;
  if p_key = 'refer' then
    raise exception 'Share your invite link. You earn 1 coin when a friend installs and registers.';
  end if;
  select * into k from public.earn_tasks where key = p_key and is_active;
  if not found then raise exception 'Invalid task'; end if;
  insert into public.user_tasks (user_id, task_key) values (me, p_key)
    on conflict do nothing;
  if not found then return false; end if;
  update public.profiles set coins = coins + k.reward_coins where id = me;
  insert into public.coin_transactions (user_id, amount, label, kind)
    values (me, k.reward_coins, k.history_label, 'earn');
  return true;
end $$;

-- Called by the new user after registration with the referrer's profile id.
create or replace function public.accept_referral(p_referrer_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  reward integer;
  hist text;
begin
  if me is null then raise exception 'Sign in required'; end if;
  if p_referrer_id is null then return false; end if;
  if p_referrer_id = me then return false; end if;

  if not exists (select 1 from public.profiles where id = p_referrer_id) then
    return false;
  end if;

  -- Already attributed (this user was referred before).
  if exists (select 1 from public.referrals where referred_id = me) then
    return false;
  end if;

  insert into public.referrals (referred_id, referrer_id)
  values (me, p_referrer_id);

  select reward_coins, history_label
    into reward, hist
  from public.earn_tasks
  where key = 'refer' and is_active;

  if reward is null then
    reward := 1;
    hist := 'Friend joined with your invite';
  end if;

  update public.profiles
  set coins = coins + reward
  where id = p_referrer_id;

  insert into public.coin_transactions (user_id, amount, label, kind)
  values (p_referrer_id, reward, hist, 'earn');

  return true;
end $$;

revoke all on function public.accept_referral(uuid) from public, anon;
grant execute on function public.accept_referral(uuid) to authenticated;

commit;
