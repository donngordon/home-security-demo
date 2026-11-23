-- ============================================================================
--  GORDON PROTECTION — Supabase database schema + security rules
--  Run this ONCE in your Supabase project: Dashboard -> SQL Editor -> New query
--  -> paste this whole file -> Run.  It is safe to re-run (idempotent).
-- ============================================================================

-- ---------- TABLES ----------------------------------------------------------

-- One row per customer (and per admin). Linked 1:1 to the auth user.
create table if not exists public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  email         text,
  full_name     text default '',
  phone         text default '',
  address       text default '',
  role          text not null default 'customer' check (role in ('customer','admin')),
  plan          text not null default 'Essential' check (plan in ('Essential','Complete','Estate')),
  monthly_price numeric(8,2) not null default 19.99,
  status        text not null default 'pending'
                  check (status in ('pending','active','past_due','suspended','cancelled')),
  autopay       boolean not null default false,
  card_last4    text default '',
  next_due      date,
  created_at    timestamptz not null default now()
);

-- Devices on a customer's system (panel, cameras, sensors...).
create table if not exists public.devices (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  name        text not null,
  kind        text default 'sensor',
  status      text not null default 'healthy' check (status in ('healthy','offline','fault')),
  last_check  timestamptz default now(),
  created_at  timestamptz not null default now()
);

-- Billing history.
create table if not exists public.invoices (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  amount      numeric(8,2) not null,
  period      text,
  status      text not null default 'due' check (status in ('paid','due','failed')),
  issued_on   date not null default current_date,
  paid_on     date,
  created_at  timestamptz not null default now()
);

create index if not exists idx_devices_user  on public.devices(user_id);
create index if not exists idx_invoices_user on public.invoices(user_id);

-- ---------- HELPER: am I an admin? -----------------------------------------
-- SECURITY DEFINER so it can read profiles without tripping row-level security
-- (avoids infinite recursion inside the profiles policies).
create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

-- ---------- AUTO-CREATE a profile when someone signs up ---------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'full_name',''))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- GUARD: customers can edit contact info, never money/role --------
create or replace function public.guard_profile_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Only revert sensitive fields for a logged-in NON-admin customer.
  -- auth.uid() is null for service-role / SQL-editor / server admin ops,
  -- which must be allowed to promote the first admin and manage accounts.
  if auth.uid() is not null and not public.is_admin() then
    new.role          := old.role;
    new.plan          := old.plan;
    new.monthly_price := old.monthly_price;
    new.status        := old.status;
    new.next_due      := old.next_due;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_profile on public.profiles;
create trigger trg_guard_profile
  before update on public.profiles
  for each row execute function public.guard_profile_update();

-- ---------- ROW-LEVEL SECURITY ----------------------------------------------
alter table public.profiles enable row level security;
alter table public.devices  enable row level security;
alter table public.invoices enable row level security;

-- profiles: see/edit your own row; admins see/edit everyone.
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select using ( id = auth.uid() or public.is_admin() );

drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles
  for update using ( id = auth.uid() or public.is_admin() )
             with check ( id = auth.uid() or public.is_admin() );

drop policy if exists profiles_admin_insert on public.profiles;
create policy profiles_admin_insert on public.profiles
  for insert with check ( public.is_admin() );

drop policy if exists profiles_admin_delete on public.profiles;
create policy profiles_admin_delete on public.profiles
  for delete using ( public.is_admin() );

-- devices: customers read their own; admins do everything.
drop policy if exists devices_select on public.devices;
create policy devices_select on public.devices
  for select using ( user_id = auth.uid() or public.is_admin() );

drop policy if exists devices_admin_write on public.devices;
create policy devices_admin_write on public.devices
  for all using ( public.is_admin() ) with check ( public.is_admin() );

-- invoices: customers read their own; admins do everything.
drop policy if exists invoices_select on public.invoices;
create policy invoices_select on public.invoices
  for select using ( user_id = auth.uid() or public.is_admin() );

drop policy if exists invoices_admin_write on public.invoices;
create policy invoices_admin_write on public.invoices
  for all using ( public.is_admin() ) with check ( public.is_admin() );

-- ============================================================================
--  AFTER you sign up your own account in the app, promote it to admin by
--  running this once (replace the email with the one you signed up with):
--
--      update public.profiles set role='admin', status='active'
--      where email = 'donn.cyber@gmail.com';
--
-- ============================================================================
