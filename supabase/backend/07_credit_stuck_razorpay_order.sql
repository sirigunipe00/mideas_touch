-- =====================================================================
-- One-time recovery: Razorpay shows Paid, but payment_orders is still
-- pending because the app failed to parse the checkout response.
--
-- 1) In Razorpay → Payments, open the payment for this order and copy
--    Payment ID (pay_...).
-- 2) Fill in the three values below and run in SQL Editor.
-- =====================================================================

-- Example for order_TzcVeQtTxrctg0 (₹1 Basic pack):
select public.complete_razorpay_payment(
  (select user_id
     from public.payment_orders
    where razorpay_order_id = 'order_TzcVeQtTxrctg0'),
  'order_TzcVeQtTxrctg0',
  'pay_PASTE_PAYMENT_ID_HERE'   -- replace with pay_... from Razorpay
);

-- Confirm:
-- select status, razorpay_payment_id, created_at, updated_at
-- from public.payment_orders
-- where razorpay_order_id = 'order_TzcVeQtTxrctg0';
