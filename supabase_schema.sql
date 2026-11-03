-- Baseline for a database with no existing app-owned tables.
-- Run docs/database-inspection.sql first. If any names overlap, adapt this migration.
BEGIN;
DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public'
 AND table_name IN ('templates','banners','app_content','profiles','user_designs','coin_transactions','shared_designs','demo_settings')) THEN
  RAISE EXCEPTION 'Existing application tables detected. Inspect and adapt this migration before applying; no changes made.';
 END IF;
END $$;
-- Supabase SQL Schema for Midas's Touch / Midas'sTouch Mobile App

-- 1. Enable UUID Extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Templates Table (Curated Designs)
CREATE TABLE IF NOT EXISTS public.templates (
    id BIGINT PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    description TEXT DEFAULT '',
    bg JSONB NOT NULL DEFAULT '["#8a6a00", "#efbf05"]'::jsonb,
    bi TEXT DEFAULT '',
    created_by TEXT DEFAULT 'Studio Team',
    is_premium BOOLEAN DEFAULT FALSE,
    cost INTEGER DEFAULT 0,
    elements JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. User Designs Table (Saved, Drafts, Completed)
CREATE TABLE IF NOT EXISTS public.user_designs (
    id BIGINT PRIMARY KEY,
    user_id TEXT,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    description TEXT DEFAULT '',
    bg JSONB NOT NULL DEFAULT '["#8a6a00", "#efbf05"]'::jsonb,
    bi TEXT DEFAULT '',
    created_by TEXT DEFAULT 'You',
    status TEXT DEFAULT 'Draft',
    modified_text TEXT DEFAULT 'Just now',
    elements JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. User Profiles Table
CREATE TABLE IF NOT EXISTS public.profiles (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT DEFAULT '',
    phone TEXT NOT NULL DEFAULT '',
    role TEXT DEFAULT 'customer',
    coins INTEGER NOT NULL DEFAULT 0 CHECK (coins >= 0),
    unlocked_templates JSONB DEFAULT '[]'::jsonb,
    completed_tasks JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Coin Transactions Table
CREATE TABLE IF NOT EXISTS public.coin_transactions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    label TEXT NOT NULL,
    amount INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 6. Banners Table
CREATE TABLE IF NOT EXISTS public.banners (
    id SERIAL PRIMARY KEY,
    tag TEXT NOT NULL,
    title TEXT NOT NULL,
    subtitle TEXT NOT NULL,
    button_text TEXT NOT NULL,
    action TEXT NOT NULL,
    gradient_colors JSONB NOT NULL,
    is_dark BOOLEAN DEFAULT FALSE
);

ALTER TABLE public.templates ADD COLUMN IF NOT EXISTS owner_id text;
CREATE TABLE IF NOT EXISTS public.app_content (id text PRIMARY KEY, content jsonb NOT NULL);
CREATE TABLE IF NOT EXISTS public.shared_designs (
  token uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id text NOT NULL,
  design jsonb NOT NULL, expires_at timestamptz NOT NULL DEFAULT now()+interval '30 days'
);
ALTER TABLE public.app_content ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.banners ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_designs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coin_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shared_designs ENABLE ROW LEVEL SECURITY;
CREATE POLICY catalog_read ON public.templates FOR SELECT USING (true);
CREATE POLICY content_read ON public.app_content FOR SELECT USING (true);
CREATE POLICY banner_read ON public.banners FOR SELECT USING (true);
CREATE POLICY own_templates ON public.templates FOR ALL TO authenticated
 USING (owner_id=auth.uid()::text) WITH CHECK (owner_id=auth.uid()::text AND EXISTS (SELECT 1 FROM profiles WHERE id=auth.uid()::text AND role='creator'));
CREATE POLICY own_designs ON public.user_designs FOR ALL TO authenticated
 USING (user_id=auth.uid()::text) WITH CHECK (user_id=auth.uid()::text);
CREATE POLICY own_profile_read ON public.profiles FOR SELECT TO authenticated USING (id=auth.uid()::text);
CREATE POLICY own_history ON public.coin_transactions FOR SELECT TO authenticated USING (user_id=auth.uid()::text);
CREATE POLICY shared_read ON public.shared_designs FOR SELECT TO authenticated USING (user_id=auth.uid()::text);
CREATE POLICY shared_create ON public.shared_designs FOR INSERT TO authenticated WITH CHECK (user_id=auth.uid()::text);

CREATE FUNCTION public.create_artifact_profile() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE d jsonb;
BEGIN
 INSERT INTO profiles(id,name,email,role) VALUES (new.id::text,coalesce(new.raw_user_meta_data->>'name',''),new.email,
 CASE WHEN new.raw_user_meta_data->>'role'='creator' THEN 'creator' ELSE 'customer' END);
 FOR d IN SELECT jsonb_array_elements(content->'designs') FROM app_content WHERE id='artifact' LOOP
 INSERT INTO user_designs(id,user_id,name,category,description,bg,created_by,status,modified_text,elements)
 VALUES ((extract(epoch from clock_timestamp())*1000000)::bigint,new.id::text,d->>'name',d->>'cat',d->>'desc',d->'bg',d->>'by',d->>'status',d->>'mod',d->'els');
 END LOOP;
 RETURN new;
END $$;
CREATE TRIGGER artifact_profile AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.create_artifact_profile();

CREATE FUNCTION public.read_shared_design(share_token uuid) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path=public AS $$
 SELECT design FROM shared_designs WHERE token=share_token AND expires_at>now();
$$;
REVOKE ALL ON FUNCTION public.read_shared_design(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.read_shared_design(uuid) TO anon, authenticated;

-- All balance changes are transactional; clients cannot edit balances directly.
CREATE FUNCTION public.unlock_design(template_id bigint) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE p profiles; title text;
BEGIN
 SELECT * INTO p FROM profiles WHERE id=auth.uid()::text FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Sign in required'; END IF;
 IF p.unlocked_templates @> jsonb_build_array(template_id) THEN RETURN true; END IF;
 SELECT name INTO title FROM templates WHERE id=template_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Design unavailable'; END IF;
 IF p.coins<1 THEN RETURN false; END IF;
 UPDATE profiles SET coins=coins-1,unlocked_templates=unlocked_templates||jsonb_build_array(template_id) WHERE id=p.id;
 INSERT INTO coin_transactions(id,user_id,label,amount) VALUES(gen_random_uuid()::text,p.id,'Unlocked '||title,-1);
 RETURN true;
END $$;
CREATE FUNCTION public.send_coins(recipient text, quantity integer) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE sender text:=auth.uid()::text; receiver text;
BEGIN
 IF sender IS NULL OR recipient IS NULL OR trim(recipient)='' OR quantity IS NULL OR quantity<=0 THEN RAISE EXCEPTION 'Invalid transfer'; END IF;
 SELECT id INTO receiver FROM profiles WHERE lower(email)=lower(trim(recipient)) OR (phone<>'' AND phone=trim(recipient));
 IF receiver IS NULL OR receiver=sender THEN RAISE EXCEPTION 'Recipient unavailable'; END IF;
 -- Lock both accounts in a deterministic order.
 PERFORM id FROM profiles WHERE id IN (sender,receiver) ORDER BY id FOR UPDATE;
 IF (SELECT coins FROM profiles WHERE id=sender)<quantity THEN RETURN false; END IF;
 UPDATE profiles SET coins=coins-quantity WHERE id=sender;
 UPDATE profiles SET coins=coins+quantity WHERE id=receiver;
 INSERT INTO coin_transactions(id,user_id,label,amount) VALUES
 (gen_random_uuid()::text,sender,'Sent to '||recipient,-quantity),
 (gen_random_uuid()::text,receiver,'Received coins',quantity);
 RETURN true;
END $$;
-- Matches the artifact's explicitly simulated rewards/purchases. Disable for production.
CREATE TABLE IF NOT EXISTS public.demo_settings(id boolean PRIMARY KEY DEFAULT true CHECK(id), enabled boolean NOT NULL DEFAULT false);
INSERT INTO demo_settings VALUES(true,false) ON CONFLICT DO NOTHING;
CREATE FUNCTION public.demo_coins(action text, pack_price integer DEFAULT 0) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE p profiles; amount integer; label text;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM demo_settings WHERE enabled) THEN RAISE EXCEPTION 'Demo rewards and payments are disabled'; END IF;
 SELECT * INTO p FROM profiles WHERE id=auth.uid()::text FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Sign in required'; END IF;
 IF action='buy' THEN
  amount:=CASE pack_price WHEN 10 THEN 1 WHEN 50 THEN 7 WHEN 100 THEN 15 ELSE 0 END;
  IF amount=0 THEN RAISE EXCEPTION 'Invalid pack'; END IF;
  label:='Bought ₹'||pack_price||' pack (demo)';
 ELSE
  IF action NOT IN ('f','r','t') THEN RAISE EXCEPTION 'Invalid task'; END IF;
  IF coalesce((p.completed_tasks->>action)::boolean,false) THEN RETURN; END IF;
  amount:=1; label:=CASE action WHEN 'f' THEN 'Followed us' WHEN 'r' THEN 'Friend accepted your invite' ELSE 'Tagged us' END;
  UPDATE profiles SET completed_tasks=jsonb_set(completed_tasks,ARRAY[action],'true') WHERE id=p.id;
 END IF;
 UPDATE profiles SET coins=coins+amount WHERE id=p.id;
 INSERT INTO coin_transactions(id,user_id,label,amount) VALUES(gen_random_uuid()::text,p.id,label,amount);
END $$;
REVOKE ALL ON FUNCTION public.unlock_design(bigint),public.send_coins(text,integer),public.demo_coins(text,integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.unlock_design(bigint),public.send_coins(text,integer),public.demo_coins(text,integer) TO authenticated;
ALTER TABLE public.demo_settings ENABLE ROW LEVEL SECURITY;
INSERT INTO storage.buckets(id,name,public) VALUES('design-assets','design-assets',true) ON CONFLICT(id) DO NOTHING;
CREATE POLICY asset_read ON storage.objects FOR SELECT USING(bucket_id='design-assets');
CREATE POLICY asset_upload ON storage.objects FOR INSERT TO authenticated WITH CHECK(bucket_id='design-assets' AND (storage.foldername(name))[1]=auth.uid()::text);


INSERT INTO public.templates (id,name,category,description,bg,bi,created_by,is_premium,cost,elements) VALUES (1,'Diwali Sale','Festivals','Festive offer poster with a glowing diya.','["#7c2d12", "#f59e0b"]'::jsonb,'','Studio Team',false,0,'[{"k": "t", "x": 8, "y": 9, "w": 84, "tx": "Diwali\nSale", "f": "Playfair Display", "s": 44, "c": "#ffffff", "b": 1, "a": "center"}, {"k": "i", "x": 29, "y": 37, "w": 42, "e": "🪔", "photo": 1}, {"k": "s", "x": 12, "y": 77, "w": 76, "h": 12, "fill": "rgba(0,0,0,.28)", "rad": "999px"}, {"k": "t", "x": 12, "y": 79.6, "w": 76, "tx": "Up to 50% OFF", "f": "Poppins", "s": 18, "c": "#ffffff", "a": "center"}]'::jsonb) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.templates (id,name,category,description,bg,bi,created_by,is_premium,cost,elements) VALUES (2,'Weekend Offer','Offers','Bold weekend discount creative for shops.','["#4c1d95", "#ec4899"]'::jsonb,'','Studio Team',true,149,'[{"k": "t", "x": 8, "y": 9, "w": 84, "tx": "Weekend\nOffer", "f": "Bebas Neue", "s": 44, "c": "#ffffff", "b": 1, "a": "center"}, {"k": "i", "x": 29, "y": 37, "w": 42, "e": "🛍️", "photo": 1}, {"k": "s", "x": 12, "y": 77, "w": 76, "h": 12, "fill": "rgba(0,0,0,.28)", "rad": "999px"}, {"k": "t", "x": 12, "y": 79.6, "w": 76, "tx": "Flat 30% on everything", "f": "Poppins", "s": 18, "c": "#ffffff", "a": "center"}]'::jsonb) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.templates (id,name,category,description,bg,bi,created_by,is_premium,cost,elements) VALUES (3,'Birthday Bash','Greetings','A cheerful birthday invitation.','["#0e7490", "#a78bfa"]'::jsonb,'','You',false,0,'[{"k": "t", "x": 8, "y": 9, "w": 84, "tx": "Happy\nBirthday", "f": "Pacifico", "s": 44, "c": "#ffffff", "b": 1, "a": "center"}, {"k": "i", "x": 29, "y": 37, "w": 42, "e": "🎂", "photo": 1}, {"k": "s", "x": 12, "y": 77, "w": 76, "h": 12, "fill": "rgba(0,0,0,.28)", "rad": "999px"}, {"k": "t", "x": 12, "y": 79.6, "w": 76, "tx": "Join the party at 7 PM", "f": "Poppins", "s": 18, "c": "#ffffff", "a": "center"}]'::jsonb) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.templates (id,name,category,description,bg,bi,created_by,is_premium,cost,elements) VALUES (4,'Restaurant Special','Food','Daily special card for cafes and restaurants.','["#991b1b", "#f97316"]'::jsonb,'','Studio Team',true,129,'[{"k": "t", "x": 8, "y": 9, "w": 84, "tx": "Chef’s\nSpecial", "f": "Playfair Display", "s": 44, "c": "#fff7ed", "b": 1, "a": "center"}, {"k": "i", "x": 29, "y": 37, "w": 42, "e": "🍔", "photo": 1}, {"k": "s", "x": 12, "y": 77, "w": 76, "h": 12, "fill": "rgba(0,0,0,.28)", "rad": "999px"}, {"k": "t", "x": 12, "y": 79.6, "w": 76, "tx": "Fresh and hot, every day", "f": "Poppins", "s": 18, "c": "#fff7ed", "a": "center"}]'::jsonb) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.templates (id,name,category,description,bg,bi,created_by,is_premium,cost,elements) VALUES (5,'Independence Day','Festivals','Patriotic greeting in Hindi.','["#ea580c", "#15803d"]'::jsonb,'','Studio Team',false,0,'[{"k": "t", "x": 8, "y": 9, "w": 84, "tx": "स्वतंत्रता\nदिवस", "f": "Noto Sans Devanagari", "s": 44, "c": "#ffffff", "b": 1, "a": "center"}, {"k": "i", "x": 29, "y": 37, "w": 42, "e": "🇮🇳", "photo": 1}, {"k": "s", "x": 12, "y": 77, "w": 76, "h": 12, "fill": "rgba(0,0,0,.28)", "rad": "999px"}, {"k": "t", "x": 12, "y": 79.6, "w": 76, "tx": "शुभकामनाएं", "f": "Poppins", "s": 18, "c": "#ffffff", "a": "center"}]'::jsonb) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.templates (id,name,category,description,bg,bi,created_by,is_premium,cost,elements) VALUES (6,'Grand Opening','Events','Announce your new store opening.','["#1e3a8a", "#06b6d4"]'::jsonb,'','You',true,199,'[{"k": "t", "x": 8, "y": 9, "w": 84, "tx": "Grand\nOpening", "f": "Bebas Neue", "s": 44, "c": "#ffffff", "b": 1, "a": "center"}, {"k": "i", "x": 29, "y": 37, "w": 42, "e": "🎉", "photo": 1}, {"k": "s", "x": 12, "y": 77, "w": 76, "h": 12, "fill": "rgba(0,0,0,.28)", "rad": "999px"}, {"k": "t", "x": 12, "y": 79.6, "w": 76, "tx": "This Saturday, 10 AM", "f": "Poppins", "s": 18, "c": "#ffffff", "a": "center"}]'::jsonb) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.templates (id,name,category,description,bg,bi,created_by,is_premium,cost,elements) VALUES (7,'New Arrival','Retail','Launch card for new products.','["#111827", "#6d28d9"]'::jsonb,'','Studio Team',false,0,'[{"k": "t", "x": 8, "y": 9, "w": 84, "tx": "New\nArrival", "f": "Poppins", "s": 44, "c": "#ffffff", "b": 1, "a": "center"}, {"k": "i", "x": 29, "y": 37, "w": 42, "e": "👟", "photo": 1}, {"k": "s", "x": 12, "y": 77, "w": 76, "h": 12, "fill": "rgba(0,0,0,.28)", "rad": "999px"}, {"k": "t", "x": 12, "y": 79.6, "w": 76, "tx": "Now in stores", "f": "Poppins", "s": 18, "c": "#ffffff", "a": "center"}]'::jsonb) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.templates (id,name,category,description,bg,bi,created_by,is_premium,cost,elements) VALUES (8,'Summer Sale','Seasonal','Bright seasonal sale creative.','["#f59e0b", "#ef4444"]'::jsonb,'','Studio Team',true,119,'[{"k": "t", "x": 8, "y": 9, "w": 84, "tx": "Summer\nSale", "f": "Pacifico", "s": 44, "c": "#ffffff", "b": 1, "a": "center"}, {"k": "i", "x": 29, "y": 37, "w": 42, "e": "☀️", "photo": 1}, {"k": "s", "x": 12, "y": 77, "w": 76, "h": 12, "fill": "rgba(0,0,0,.28)", "rad": "999px"}, {"k": "t", "x": 12, "y": 79.6, "w": 76, "tx": "Cool deals, hot prices", "f": "Poppins", "s": 18, "c": "#ffffff", "a": "center"}]'::jsonb) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.banners (id,tag,title,subtitle,button_text,action,gradient_colors,is_dark) VALUES (1,'Create. Customize. Share.','Create beautiful promotional images in minutes','Pick a design, customize it, and share your design.','Start Creating','use_1','["#efbf05", "#f6da6f"]'::jsonb,false) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.banners (id,tag,title,subtitle,button_text,action,gradient_colors,is_dark) VALUES (2,'🪙 Earn free coins','Follow, refer and tag to earn coins','1 coin for each action.','Earn coins','wallet','["#f6da6f", "#faeaac"]'::jsonb,false) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.banners (id,tag,title,subtitle,button_text,action,gradient_colors,is_dark) VALUES (3,'Buy coins','Get up to 15 coins for ₹100','₹10 for 1 coin. Bigger packs give bonus coins.','See packs','wallet','["#1d1700", "#4a3c0c"]'::jsonb,true) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.banners (id,tag,title,subtitle,button_text,action,gradient_colors,is_dark) VALUES (4,'Festival season','Festive designs are here','Explore for free. Customise with 1 coin.','Explore','festivals','["#e8a20a", "#efbf05"]'::jsonb,false) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.app_content (id,content) VALUES ('artifact','{"categories": ["Festivals", "Offers", "Promotions", "Business", "Events", "Food", "Retail", "Announcements", "Greetings", "Social Media", "Seasonal", "Other"], "fonts": ["Poppins", "Playfair Display", "Pacifico", "Bebas Neue", "Noto Sans Devanagari", "Hind", "Baloo 2"], "assets": [["🪔", "diya diwali lamp"], ["🍔", "burger food"], ["🎂", "cake birthday"], ["🛍️", "shopping sale offer"], ["🎉", "party event"], ["☀️", "summer sun"], ["👟", "shoes retail"], ["🍕", "pizza restaurant food"], ["🎁", "gift offer"], ["🌸", "flower spring"], ["☕", "coffee cafe"], ["🚀", "launch new"]], "backgrounds": [["#8a6a00", "#efbf05"], ["#7c2d12", "#f59e0b"], ["#0e7490", "#a78bfa"], ["#111827", "#6d28d9"], ["#15803d", "#facc15"], ["#be185d", "#fb923c"]], "translations": {"en": {"home": "Home", "se": "Search", "md": "My Designs", "me": "Profile", "studio": "Studio", "h1": "Create beautiful promotional images in minutes", "sub": "Pick a design, customize it, and share your design.", "start": "Start Creating", "ph": "Search designs, occasions...", "pop": "Popular Designs", "trend": "Trending Designs", "rec": "Recently Added", "use": "Use", "tag": "Create. Customize. Share.", "save": "Save", "prev": "Preview", "cust": "Customize Design", "sbi": "Search by Image", "cat": "Categories", "exp": "Export JPG", "share": "Share", "login": "Login", "free": "Free", "prem": "Premium"}, "hi": {"home": "होम", "se": "खोजें", "md": "मेरे डिज़ाइन", "me": "प्रोफ़ाइल", "studio": "स्टूडियो", "h1": "मिनटों में सुंदर प्रचार चित्र बनाएं", "sub": "डिज़ाइन चुनें, बदलें और अपना डिज़ाइन साझा करें।", "start": "बनाना शुरू करें", "ph": "डिज़ाइन, अवसर खोजें...", "pop": "लोकप्रिय डिज़ाइन", "trend": "ट्रेंडिंग डिज़ाइन", "rec": "हाल ही में जोड़े गए", "use": "इस्तेमाल करें", "tag": "बनाएं। बदलें। साझा करें।", "save": "सहेजें", "prev": "पूर्वावलोकन", "cust": "डिज़ाइन बदलें", "sbi": "चित्र से खोजें", "cat": "श्रेणियां", "exp": "JPG निर्यात", "share": "साझा करें", "login": "लॉगिन", "free": "मुफ़्त", "prem": "प्रीमियम"}}, "designs": [{"id": 101, "name": "Diwali Promotion", "cat": "Festivals", "desc": "Festive offer poster with a glowing diya.", "bg": ["#7c2d12", "#f59e0b"], "els": [{"k": "t", "x": 8, "y": 9, "w": 84, "tx": "Diwali\nSale", "f": "Playfair Display", "s": 44, "c": "#ffffff", "b": 1, "a": "center"}, {"k": "i", "x": 29, "y": 37, "w": 42, "e": "🪔", "photo": 1}, {"k": "s", "x": 12, "y": 77, "w": 76, "h": 12, "fill": "rgba(0,0,0,.28)", "rad": "999px"}, {"k": "t", "x": 12, "y": 79.6, "w": 76, "tx": "Up to 50% OFF", "f": "Poppins", "s": 18, "c": "#ffffff", "a": "center"}], "by": "Studio Team", "pm": false, "cost": 0, "status": "Completed", "mod": "Today, 10:42 AM"}, {"id": 102, "name": "Birthday Invite", "cat": "Greetings", "desc": "A cheerful birthday invitation.", "bg": ["#0e7490", "#a78bfa"], "els": [{"k": "t", "x": 8, "y": 9, "w": 84, "tx": "Happy\nBirthday", "f": "Pacifico", "s": 44, "c": "#ffffff", "b": 1, "a": "center"}, {"k": "i", "x": 29, "y": 37, "w": 42, "e": "🎂", "photo": 1}, {"k": "s", "x": 12, "y": 77, "w": 76, "h": 12, "fill": "rgba(0,0,0,.28)", "rad": "999px"}, {"k": "t", "x": 12, "y": 79.6, "w": 76, "tx": "Join the party at 7 PM", "f": "Poppins", "s": 18, "c": "#ffffff", "a": "center"}], "by": "You", "pm": false, "cost": 0, "status": "Draft", "mod": "Yesterday, 6:15 PM"}, {"id": 103, "name": "Independence Day Wishes", "cat": "Festivals", "desc": "Patriotic greeting in Hindi.", "bg": ["#ea580c", "#15803d"], "els": [{"k": "t", "x": 8, "y": 9, "w": 84, "tx": "स्वतंत्रता\nदिवस", "f": "Noto Sans Devanagari", "s": 44, "c": "#ffffff", "b": 1, "a": "center"}, {"k": "i", "x": 29, "y": 37, "w": 42, "e": "🇮🇳", "photo": 1}, {"k": "s", "x": 12, "y": 77, "w": 76, "h": 12, "fill": "rgba(0,0,0,.28)", "rad": "999px"}, {"k": "t", "x": 12, "y": 79.6, "w": 76, "tx": "शुभकामनाएं", "f": "Poppins", "s": 18, "c": "#ffffff", "a": "center"}], "by": "Studio Team", "pm": false, "cost": 0, "status": "Draft", "mod": "Oct 28, 4:05 PM"}], "coin_packs": [{"name": "Basic", "price": 10, "coins": 1, "bonus": 0}, {"name": "Advance", "price": 50, "coins": 5, "bonus": 2}, {"name": "Pro", "price": 100, "coins": 10, "bonus": 5}], "banners": [{"id": 1, "tag": "Create. Customize. Share.", "title": "Create beautiful promotional images in minutes", "subtitle": "Pick a design, customize it, and share your design.", "button_text": "Start Creating", "action": "use_1", "gradient_colors": ["#efbf05", "#f6da6f"], "is_dark": false}, {"id": 2, "tag": "🪙 Earn free coins", "title": "Follow, refer and tag to earn coins", "subtitle": "1 coin for each action.", "button_text": "Earn coins", "action": "wallet", "gradient_colors": ["#f6da6f", "#faeaac"], "is_dark": false}, {"id": 3, "tag": "Buy coins", "title": "Get up to 15 coins for ₹100", "subtitle": "₹10 for 1 coin. Bigger packs give bonus coins.", "button_text": "See packs", "action": "wallet", "gradient_colors": ["#1d1700", "#4a3c0c"], "is_dark": true}, {"id": 4, "tag": "Festival season", "title": "Festive designs are here", "subtitle": "Explore for free. Customise with 1 coin.", "button_text": "Explore", "action": "festivals", "gradient_colors": ["#e8a20a", "#efbf05"], "is_dark": false}], "branding": {"light": "artifact/brand_light.png", "dark": "artifact/brand_dark.png"}, "studio_stats": {"uses": "1,284", "earnings": "₹12,480"}}'::jsonb) ON CONFLICT (id) DO NOTHING;

COMMIT;
