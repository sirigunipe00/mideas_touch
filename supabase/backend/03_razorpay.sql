-- =====================================================================
-- Midas's Touch — Razorpay payments (Test → Live by swapping secrets).
--
-- Run in the Supabase SQL Editor after 01_schema.sql / 02_seed.sql.
-- Then deploy Edge Functions: create-razorpay-order, verify-razorpay-payment.
-- =====================================================================
begin;

-- Pending / paid / failed checkout attempts. Written only by Edge Functions
-- (service role). Users may read their own rows.
create table if not exists public.payment_orders (
  id                   uuid primary key default gen_random_uuid(),
  user_id              uuid not null references public.profiles (id) on delete cascade,
  pack_id              bigint not null references public.coin_packs (id),
  amount_paise         integer not null check (amount_paise > 0),
  currency             text not null default 'INR',
  razorpay_order_id    text not null unique,
  razorpay_payment_id  text,
  status               text not null default 'pending'
                         check (status in ('pending', 'paid', 'failed')),
  -- Text IST timestamps (same style as templates): 2026-11-13 15-08-19
  created_at           text not null
    default to_char((now() at time zone 'Asia/Kolkata'), 'YYYY-MM-DD HH24-MI-SS'),
  updated_at           text not null
    default to_char((now() at time zone 'Asia/Kolkata'), 'YYYY-MM-DD HH24-MI-SS')
);
create index if not exists payment_orders_user_idx
  on public.payment_orders (user_id, created_at desc);

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

drop trigger if exists payment_orders_updated on public.payment_orders;
create trigger payment_orders_updated before update on public.payment_orders
  for each row execute function public.set_payment_orders_updated_at();

alter table public.payment_orders enable row level security;

revoke all on public.payment_orders from anon, authenticated;
grant select on public.payment_orders to authenticated;

drop policy if exists payment_orders_read_own on public.payment_orders;
create policy payment_orders_read_own on public.payment_orders
  for select to authenticated
  using (user_id = auth.uid());

-- Idempotent credit after a verified Razorpay payment.
-- Called only by the verify Edge Function (service role).
create or replace function public.complete_razorpay_payment(
  p_user_id uuid,
  p_razorpay_order_id text,
  p_razorpay_payment_id text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  o public.payment_orders;
  k public.coin_packs;
  total integer;
begin
  if p_user_id is null then
    raise exception 'Sign in required';
  end if;

  select * into o
  from public.payment_orders
  where razorpay_order_id = p_razorpay_order_id
  for update;

  if not found then
    raise exception 'Order not found';
  end if;

  if o.user_id <> p_user_id then
    raise exception 'Order does not belong to this user';
  end if;

  if o.status = 'paid' then
    return jsonb_build_object(
      'ok', true,
      'already_paid', true,
      'coins', (select coins from public.profiles where id = p_user_id)
    );
  end if;

  if o.status <> 'pending' then
    raise exception 'Order is not payable';
  end if;

  select * into k from public.coin_packs where id = o.pack_id and is_active;
  if not found then
    raise exception 'Invalid pack';
  end if;

  total := k.coins + k.bonus_coins;

  update public.payment_orders
  set status = 'paid',
      razorpay_payment_id = p_razorpay_payment_id
  where id = o.id;

  update public.profiles
  set coins = coins + total
  where id = p_user_id;

  insert into public.coin_transactions (user_id, amount, label, kind)
  values (
    p_user_id,
    total,
    'Bought ₹' || k.price_inr || ' pack',
    'purchase'
  );

  return jsonb_build_object(
    'ok', true,
    'already_paid', false,
    'coins', (select coins from public.profiles where id = p_user_id),
    'credited', total
  );
end $$;

revoke all on function public.complete_razorpay_payment(uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.complete_razorpay_payment(uuid, text, text)
  to service_role;

-- Stop the demo mint path (Buy no longer credits without payment).
insert into public.app_settings (key, value)
values ('demo_payments_enabled', 'false'::jsonb)
on conflict (key) do update set value = excluded.value;

commit;
