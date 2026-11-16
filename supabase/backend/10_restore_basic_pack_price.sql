-- Restore Basic pack to ₹10 (was ₹1 for testing).
update public.coin_packs
set price_inr = 10
where name = 'Basic';
