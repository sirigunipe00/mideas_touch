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


COMMIT;
