-- =====================================================================
-- Add user_email on unlocked_templates (filled from profiles).
-- Run once in Supabase SQL Editor.
-- =====================================================================
begin;

alter table public.unlocked_templates
  add column if not exists user_email text;

-- Backfill existing rows
update public.unlocked_templates ut
set user_email = p.email
from public.profiles p
where p.id = ut.user_id
  and (ut.user_email is null or ut.user_email = '');

-- Auto-fill on insert / update when email is missing
create or replace function public.set_unlocked_templates_user_email()
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

drop trigger if exists unlocked_templates_user_email on public.unlocked_templates;
create trigger unlocked_templates_user_email
  before insert or update on public.unlocked_templates
  for each row execute function public.set_unlocked_templates_user_email();

commit;
