-- Draft migration: review and test before production. No identity documents accepted yet.
begin;
create table public.driver_profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 username text not null check (username ~ '^[a-zA-Z0-9_]{3,32}$'),
 full_name text not null check (char_length(full_name) between 2 and 120),
 status text not null default 'pending' check (status in ('pending','approved','rejected','suspended')),
 created_at timestamptz not null default now()
);
create unique index driver_username_unique on public.driver_profiles(lower(username));
create table public.owner_accounts (id uuid primary key references auth.users(id) on delete cascade);
alter table public.owner_accounts enable row level security;
revoke all on public.owner_accounts from anon, authenticated;
create function public.is_owner() returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.owner_accounts where id=auth.uid())$$;
revoke all on function public.is_owner() from public;
grant execute on function public.is_owner() to authenticated;
alter table public.driver_profiles enable row level security;
revoke all on public.driver_profiles from anon,authenticated;
grant select on public.driver_profiles to authenticated;
grant insert(id,username,full_name) on public.driver_profiles to authenticated;
grant update(status) on public.driver_profiles to authenticated;
create policy profile_read on public.driver_profiles for select to authenticated using (id=auth.uid() or public.is_owner());
create policy profile_register on public.driver_profiles for insert to authenticated with check(id=auth.uid() and status='pending' and coalesce(auth.jwt()->>'email','') <> '');
create policy profile_review on public.driver_profiles for update to authenticated using(public.is_owner()) with check(public.is_owner());
-- Require email confirmation in Auth settings before enabling signup. JWT email itself is not proof of confirmation.
-- Backend-only owner provisioning: insert an independently verified owner UUID using privileged SQL.
-- Documents, retention, audit log, account data partitioning and access tests are required before public onboarding.
commit;
