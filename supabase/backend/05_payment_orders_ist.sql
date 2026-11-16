-- =====================================================================
-- View payment_orders timestamps in IST as: 2026-11-13 15:41:00
--
-- Keeps created_at / updated_at as timestamptz (correct storage).
-- Use this view in SQL Editor / Table view for human-readable IST times.
-- =====================================================================

create or replace view public.payment_orders_ist
with (security_invoker = true)
as
select
  id,
  user_id,
  pack_id,
  amount_paise,
  currency,
  razorpay_order_id,
  razorpay_payment_id,
  status,
  to_char(created_at at time zone 'Asia/Kolkata', 'YYYY-MM-DD HH24:MI:SS')
    as created_at_ist,
  to_char(updated_at at time zone 'Asia/Kolkata', 'YYYY-MM-DD HH24:MI:SS')
    as updated_at_ist,
  created_at,
  updated_at
from public.payment_orders;

grant select on public.payment_orders_ist to authenticated;

-- Quick check (optional):
-- select id, status, created_at_ist, updated_at_ist
-- from public.payment_orders_ist
-- order by created_at desc;
