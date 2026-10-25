create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  role text not null default 'staff' check (role in ('admin', 'staff')),
  created_at timestamptz not null default now()
);

create or replace function public.current_user_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid()
$$;

create or replace function public.is_app_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_user_role() = 'admin', false)
$$;

create or replace function public.create_staff_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, role)
  values (new.id, coalesce(new.email, ''), 'staff')
  on conflict (id) do update set email = excluded.email;
  return new;
end
$$;

drop trigger if exists create_profile_for_auth_user on auth.users;
create trigger create_profile_for_auth_user
after insert on auth.users
for each row execute procedure public.create_staff_profile();

create table if not exists public.app_data (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);

create table if not exists public.app_documents (
  id text primary key,
  contact_id text not null,
  owner_type text not null,
  name text not null,
  content_type text not null,
  purposes jsonb not null default '[]'::jsonb,
  language text not null default '',
  added_at timestamptz not null default now(),
  storage_path text not null unique
);

alter table public.profiles enable row level security;
alter table public.app_data enable row level security;
alter table public.app_documents enable row level security;

drop policy if exists "Users can read their own profile" on public.profiles;
create policy "Users can read their own profile"
on public.profiles for select to authenticated
using (id = auth.uid() or public.is_app_admin());

drop policy if exists "Admins can manage profiles" on public.profiles;
create policy "Admins can manage profiles"
on public.profiles for all to authenticated
using (public.is_app_admin())
with check (public.is_app_admin());

drop policy if exists "Admins and approved staff can read app data" on public.app_data;
create policy "Admins and approved staff can read app data"
on public.app_data for select to authenticated
using (
  public.is_app_admin()
  or (
    public.current_user_role() = 'staff'
    and key in ('my-contact-book-v1', 'my-dayanim-registry-v1')
  )
);

drop policy if exists "Admins can manage app data" on public.app_data;
create policy "Admins can manage app data"
on public.app_data for all to authenticated
using (public.is_app_admin())
with check (public.is_app_admin());

drop policy if exists "Admins and staff can read allowed documents" on public.app_documents;
create policy "Admins and staff can read allowed documents"
on public.app_documents for select to authenticated
using (
  public.is_app_admin()
  or (
    public.current_user_role() = 'staff'
    and owner_type in ('contact', 'dayanim')
  )
);

drop policy if exists "Admins can manage document metadata" on public.app_documents;
create policy "Admins can manage document metadata"
on public.app_documents for all to authenticated
using (public.is_app_admin())
with check (public.is_app_admin());

insert into storage.buckets (id, name, public)
values ('app-documents', 'app-documents', false)
on conflict (id) do update set public = false;

drop policy if exists "Admins and staff can read allowed app documents" on storage.objects;
create policy "Admins and staff can read allowed app documents"
on storage.objects for select to authenticated
using (
  bucket_id = 'app-documents'
  and (
    public.is_app_admin()
    or (
      public.current_user_role() = 'staff'
      and (storage.foldername(name))[1] in ('dayanim', 'recommendations')
    )
  )
);

drop policy if exists "Admins can manage app documents" on storage.objects;
create policy "Admins can manage app documents"
on storage.objects for all to authenticated
using (bucket_id = 'app-documents' and public.is_app_admin())
with check (bucket_id = 'app-documents' and public.is_app_admin());

grant select on public.profiles, public.app_data, public.app_documents to authenticated;
grant insert, update, delete on public.app_data, public.app_documents to authenticated;
