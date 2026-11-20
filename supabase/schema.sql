-- Run in Supabase SQL Editor. Safe to re-run (idempotent).
create extension if not exists pgcrypto with schema extensions;

-- ---------- Tables ----------
create table if not exists public.chat_rooms (
  id uuid primary key default gen_random_uuid(),
  invite_hash bytea not null unique,
  created_at timestamptz not null default now()
);

create table if not exists public.room_members (
  room_id uuid not null references public.chat_rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (room_id, user_id)
);

create table if not exists public.messages (
  id bigint generated always as identity primary key,
  room_id uuid not null references public.chat_rooms(id) on delete cascade,
  author_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 4000),
  created_at timestamptz not null default now()
);

-- For databases created with the older schema:
alter table public.messages alter column author_id set default auth.uid();

create index if not exists messages_room_id_id_idx
  on public.messages (room_id, id);

-- ---------- Row level security ----------
alter table public.chat_rooms enable row level security;
alter table public.room_members enable row level security;
alter table public.messages enable row level security;

drop policy if exists "members can read own room membership" on public.room_members;
create policy "members can read own room membership"
on public.room_members for select to authenticated
using (user_id = auth.uid());

drop policy if exists "members can read messages" on public.messages;
create policy "members can read messages"
on public.messages for select to authenticated
using (exists (
  select 1 from public.room_members m
  where m.room_id = messages.room_id and m.user_id = auth.uid()
));

drop policy if exists "members can send messages as themselves" on public.messages;
create policy "members can send messages as themselves"
on public.messages for insert to authenticated
with check (
  author_id = auth.uid()
  and exists (
    select 1 from public.room_members m
    where m.room_id = messages.room_id and m.user_id = auth.uid()
  )
);

-- ---------- Functions ----------
-- search_path is empty, so every object below is schema-qualified.
create or replace function public.create_room()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room uuid;
  v_code text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  v_code := encode(extensions.gen_random_bytes(8), 'hex');  -- 16 hex chars
  insert into public.chat_rooms(invite_hash)
  values (extensions.digest(v_code, 'sha256'))
  returning id into v_room;
  insert into public.room_members(room_id, user_id) values (v_room, auth.uid());
  return jsonb_build_object('room_id', v_room, 'invite_code', v_code);
end;
$$;

create or replace function public.join_room(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_code is null or length(p_code) <> 16 then raise exception 'Invalid invite code'; end if;

  -- Lock the room row so two people can't join at the same moment.
  select id into v_room
  from public.chat_rooms
  where invite_hash = extensions.digest(lower(p_code), 'sha256')
  for update;
  if v_room is null then raise exception 'Invalid invite code'; end if;

  -- One-to-one only: a room holds at most 2 members.
  if not exists (
       select 1 from public.room_members
       where room_id = v_room and user_id = auth.uid())
     and (select count(*) from public.room_members where room_id = v_room) >= 2
  then
    raise exception 'Room full';
  end if;

  insert into public.room_members(room_id, user_id)
  values (v_room, auth.uid())
  on conflict do nothing;
  return jsonb_build_object('room_id', v_room);
end;
$$;

-- ---------- Privileges ----------
-- Supabase's default privileges grant broad access; reset, then grant minimum.
revoke all on public.chat_rooms, public.room_members, public.messages
  from anon, authenticated;
grant select on public.room_members to authenticated;
grant select, insert on public.messages to authenticated;

revoke all on function public.create_room() from public, anon;
revoke all on function public.join_room(text) from public, anon;
grant execute on function public.create_room() to authenticated;
grant execute on function public.join_room(text) to authenticated;

-- ---------- Realtime ----------
-- Ignore the error if the table is already in the publication.
do $$
begin
  alter publication supabase_realtime add table public.messages;
exception when duplicate_object then null;
end $$;
