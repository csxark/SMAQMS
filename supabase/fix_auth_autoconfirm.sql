-- ============================================================================
-- Fix: Auto-confirm Emails, Prevent Signup Limits & Enable Realtime Sync
-- ============================================================================
-- Run this in your Supabase SQL Editor:
-- https://supabase.com/dashboard/project/dadliwnisugumtwleipm/sql/new

-- 1. Auto-confirm all existing users currently stuck in unconfirmed state
update auth.users
set email_confirmed_at = coalesce(email_confirmed_at, now())
where email_confirmed_at is null;

-- 2. Automatically confirm new users on insert into auth.users so no email confirmation is required
create or replace function public.handle_auto_confirm_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.email_confirmed_at is null then
    new.email_confirmed_at := now();
  end if;
  return new;
end $$;

drop trigger if exists on_auth_user_auto_confirm on auth.users;
create trigger on_auth_user_auto_confirm
  before insert on auth.users
  for each row execute function public.handle_auto_confirm_user();

-- 3. Robust patient handler on user creation
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_name text;
  v_phone text;
begin
  if new.raw_app_meta_data->>'staff' is not null then
    return new;
  end if;

  v_name := trim(coalesce(new.raw_user_meta_data->>'name', ''));
  v_phone := regexp_replace(coalesce(new.raw_user_meta_data->>'phone', ''), '[\s-]', '', 'g');

  if char_length(v_name) < 2 or char_length(v_name) > 100 then
    v_name := coalesce(nullif(trim(split_part(new.email, '@', 1)), ''), 'Patient');
  end if;

  if v_phone !~ '^\+?[0-9]{7,15}$' then
    v_phone := '+10000000000';
  end if;

  insert into public.patients(user_id, name, email, phone)
  values (new.id, v_name, lower(new.email), v_phone)
  on conflict (user_id) do update
    set name = excluded.name,
        email = excluded.email,
        phone = excluded.phone,
        updated_at = now();

  insert into public.user_roles(user_id, role)
  values (new.id, 'patient')
  on conflict do nothing;

  return new;
end $$;

-- 4. Ensure Realtime publication and replica identity for live sync across roles
alter table public.queue_entries replica identity full;
alter table public.appointments replica identity full;
alter table public.consultations replica identity full;

do $$
begin
  begin
    alter publication supabase_realtime add table public.appointments;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.queue_entries;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.consultations;
  exception when duplicate_object then null;
  end;
end $$;
