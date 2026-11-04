-- =====================================================================
-- Midas's Touch — STEP 2: catalogue data.
--
-- Run after 01_schema.sql. The 28 template pictures must also be uploaded to
-- the `app-assets` bucket under templates/ (see tool/seed_storage.py).
--
-- Every value below came from the former in-app dummy catalogue (categories,
-- fonts, gradients, stock images, coin packs, tasks, banners) except the
-- templates: those are the 28 Diwali pictures supplied for this project.
-- =====================================================================
begin;

insert into public.categories (name, sort_order) values
  ('Festivals', 1), ('Offers', 2), ('Promotions', 3), ('Business', 4),
  ('Events', 5), ('Food', 6), ('Retail', 7), ('Announcements', 8),
  ('Greetings', 9), ('Social Media', 10), ('Seasonal', 11), ('Other', 12);

insert into public.fonts (family, sort_order) values
  ('Poppins', 1), ('Playfair Display', 2), ('Pacifico', 3), ('Bebas Neue', 4),
  ('Noto Sans Devanagari', 5), ('Hind', 6), ('Baloo 2', 7);

insert into public.backgrounds (name, color_from, color_to, sort_order) values
  ('Gold',     '#8a6a00', '#efbf05', 1),
  ('Sunset',   '#7c2d12', '#f59e0b', 2),
  ('Lagoon',   '#0e7490', '#a78bfa', 3),
  ('Midnight', '#111827', '#6d28d9', 4),
  ('Meadow',   '#15803d', '#facc15', 5),
  ('Blossom',  '#be185d', '#fb923c', 6);

insert into public.stock_assets (emoji, keywords, sort_order) values
  ('🪔', 'diya diwali lamp',          1),
  ('🍔', 'burger food',               2),
  ('🎂', 'cake birthday',             3),
  ('🛍️', 'shopping sale offer',      4),
  ('🎉', 'party event',               5),
  ('☀️', 'summer sun',               6),
  ('👟', 'shoes retail',              7),
  ('🍕', 'pizza restaurant food',     8),
  ('🎁', 'gift offer',                9),
  ('🌸', 'flower spring',            10),
  ('☕', 'coffee cafe',              11),
  ('🚀', 'launch new',               12);

insert into public.coin_packs (name, price_inr, coins, bonus_coins, is_popular, sort_order) values
  ('Basic',   10,  1, 0, false, 1),
  ('Advance', 50,  5, 2, true,  2),
  ('Pro',    100, 10, 5, false, 3);

insert into public.earn_tasks (key, icon, title, description, button_label, history_label, sort_order) values
  ('follow', '📣', 'Follow us',      'On our social media pages',          '+1 🪙', 'Followed us',                  1),
  ('refer',  '🤝', 'Refer a friend', '1 coin when your friend accepts',    'Invite', 'Friend accepted your invite', 2),
  ('tag',    '🏷️', 'Tag us',         'Tag Midas’s Touch in your post',     '+1 🪙', 'Tagged us',                    3);

insert into public.banners
  (tag, title, body, button_label, tag_hi, title_hi, body_hi, button_label_hi,
   action, color_from, color_to, is_dark, sort_order) values
  ('Create. Customize. Share.',
   'Create beautiful promotional images in minutes',
   'Pick a design, customize it, and share your design.',
   'Start Creating',
   'बनाएं। बदलें। साझा करें।',
   'मिनटों में सुंदर प्रचार चित्र बनाएं',
   'डिज़ाइन चुनें, बदलें और अपना डिज़ाइन साझा करें।',
   'बनाना शुरू करें',
   'startCreating', '#efbf05', '#f6da6f', false, 1),
  ('🪙 Earn free coins',
   'Follow, refer and tag to earn coins',
   '1 coin for each action.',
   'Earn coins', null, null, null, null,
   'earnCoins', '#f6da6f', '#faeaac', false, 2),
  ('Buy coins',
   'Get up to 15 coins for ₹100',
   '₹10 for 1 coin. Bigger packs give bonus coins.',
   'See packs', null, null, null, null,
   'seePacks', '#1d1700', '#4a3c0c', true, 3),
  ('Festival season',
   'Festive designs are here',
   'Explore for free. Customise with 1 coin.',
   'Explore', null, null, null, null,
   'explore', '#e8a20a', '#efbf05', false, 4);

-- DEMO PAYMENTS: the app's "Buy" button credits coins without a real payment.
-- Set to false (or delete the row) before launch.
insert into public.app_settings (key, value) values
  ('demo_payments_enabled', 'true'::jsonb);

-- ---------------------------------------------------------------------
-- Templates: the 28 Diwali pictures.
--   bg_from / bg_to  = average colour of the picture's top-left / bottom-right
--                      quarter (placeholder shown while the picture downloads)
--   background_image_path = file in bucket app-assets
-- ---------------------------------------------------------------------
insert into public.templates
  (name, category_id, description, bg_from, bg_to, background_image_path, sort_order)
select v.name, c.id, v.descr, v.bg_from, v.bg_to, 'templates/' || v.file, v.ord
from (values
  ('Diwali Greeting 01', 'Festivals',  'Warm Diwali wishes greeting.',           '#adaaa6', '#eee6d5', 'diwali-greeting-01.jpg',  1),
  ('Diwali Greeting 02', 'Festivals',  'Warm Diwali wishes greeting.',           '#f0c699', '#f3e3cf', 'diwali-greeting-02.jpg',  2),
  ('Diwali Greeting 03', 'Festivals',  'Warm Diwali wishes greeting.',           '#dac1a4', '#d9ba93', 'diwali-greeting-03.jpg',  3),
  ('Diwali Greeting 04', 'Festivals',  'Warm Diwali wishes greeting.',           '#c6a183', '#ecdac4', 'diwali-greeting-04.jpg',  4),
  ('Diwali Greeting 05', 'Festivals',  'Warm Diwali wishes greeting.',           '#80502e', '#0c3868', 'diwali-greeting-05.jpg',  5),
  ('Diwali Greeting 06', 'Festivals',  'Warm Diwali wishes greeting.',           '#daab81', '#efd7bb', 'diwali-greeting-06.jpg',  6),
  ('Diwali Greeting 07', 'Festivals',  'Warm Diwali wishes greeting.',           '#1d2b40', '#523a35', 'diwali-greeting-07.jpg',  7),
  ('Diwali Greeting 08', 'Festivals',  'Warm Diwali wishes greeting.',           '#f6e3cf', '#adaea5', 'diwali-greeting-08.jpg',  8),
  ('Diwali Greeting 09', 'Festivals',  'Warm Diwali wishes greeting.',           '#172454', '#31264f', 'diwali-greeting-09.jpg',  9),
  ('Diwali Greeting 10', 'Festivals',  'Warm Diwali wishes greeting.',           '#cfbaa7', '#f2e1c9', 'diwali-greeting-10.jpg', 10),
  ('Diwali Greeting 11', 'Festivals',  'Warm Diwali wishes greeting.',           '#cda276', '#ebc59c', 'diwali-greeting-11.jpg', 11),
  ('Diwali Greeting 12', 'Festivals',  'Warm Diwali wishes greeting.',           '#ecdec2', '#f4ead4', 'diwali-greeting-12.jpg', 12),
  ('Diwali Greeting 13', 'Festivals',  'Warm Diwali wishes greeting.',           '#374972', '#123b7b', 'diwali-greeting-13.jpg', 13),
  ('Diwali Greeting 14', 'Festivals',  'Warm Diwali wishes greeting.',           '#e9d4be', '#c49061', 'diwali-greeting-14.jpg', 14),
  ('Diwali Greeting 15', 'Festivals',  'Warm Diwali wishes greeting.',           '#172233', '#252a35', 'diwali-greeting-15.jpg', 15),
  ('Diwali Greeting 16', 'Festivals',  'Warm Diwali wishes greeting.',           '#162034', '#1f2334', 'diwali-greeting-16.jpg', 16),
  ('Diwali Greeting 17', 'Festivals',  'Warm Diwali wishes greeting.',           '#373f4c', '#604a47', 'diwali-greeting-17.jpg', 17),
  ('Diwali Greeting 18', 'Festivals',  'Warm Diwali wishes greeting.',           '#1e4763', '#64402b', 'diwali-greeting-18.jpg', 18),
  ('Diwali Greeting 19', 'Festivals',  'Warm Diwali wishes greeting.',           '#1a3654', '#825748', 'diwali-greeting-19.jpg', 19),
  ('Diwali Greeting 20', 'Festivals',  'Warm Diwali wishes greeting.',           '#c89563', '#dbb287', 'diwali-greeting-20.jpg', 20),
  ('Diwali Greeting 21', 'Festivals',  'Warm Diwali wishes greeting.',           '#a58d6c', '#f5edda', 'diwali-greeting-21.jpg', 21),
  ('Diwali Greeting 22', 'Festivals',  'Warm Diwali wishes greeting.',           '#34431a', '#323f1c', 'diwali-greeting-22.jpg', 22),
  ('Diwali Greeting 23', 'Festivals',  'Warm Diwali wishes greeting.',           '#132737', '#182e40', 'diwali-greeting-23.jpg', 23),
  ('Diwali Greeting 24', 'Festivals',  'Warm Diwali wishes greeting.',           '#243319', '#213414', 'diwali-greeting-24.jpg', 24),
  ('Diwali Greeting 25', 'Festivals',  'Warm Diwali wishes greeting.',           '#113565', '#4d474c', 'diwali-greeting-25.jpg', 25),
  ('Diwali Family Greeting',     'Greetings',  'Diwali wishes with a family celebration.',                      '#f3e6d8', '#9e7869', 'diwali-greeting-26.jpg', 26),
  ('Diwali Shopping Break',      'Promotions', 'Festive vendor-stall promotion with date, time and location.',  '#eddac8', '#c89877', 'diwali-greeting-27.jpg', 27),
  ('Diwali Celebration Invite',  'Events',     'Invitation to a Diwali celebration with date, time and place.', '#e8d9d3', '#b37b5a', 'diwali-greeting-28.jpg', 28)
) as v(name, cat, descr, bg_from, bg_to, file, ord)
join public.categories c on c.name = v.cat;

commit;
