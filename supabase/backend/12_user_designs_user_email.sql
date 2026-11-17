-- =====================================================================
-- Add user_email on user_designs (filled from profiles).
-- Run once in Supabase SQL Editor.
-- =====================================================================
begin;

alter table public.user_designs
  add column if not exists user_email text;

-- Backfill existing rows
update public.user_designs ud
set user_email = p.email
from public.profiles p
where p.id = ud.user_id
  and (ud.user_email is null or ud.user_email = '');

-- Auto-fill on insert / upsert when email is missing
create or replace function public.set_user_designs_user_email()
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

drop trigger if exists user_designs_user_email on public.user_designs;
create trigger user_designs_user_email
  before insert or update on public.user_designs
  for each row execute function public.set_user_designs_user_email();

commit;
