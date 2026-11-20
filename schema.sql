-- Run once in Supabase SQL Editor.
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.chat_rooms (
  id uuid primary key default gen_random_uuid(),
  invite_hash bytea not null unique,
  invite_used boolean not null default false,
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
  author_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(trim(body)) between 1 and 4000),
  created_at timestamptz not null default now()
);

create index if not exists idx_room_members_user_id on public.room_members(user_id);
create index if not exists idx_messages_room_created on public.messages(room_id, created_at);

alter table public.chat_rooms enable row level security;
alter table public.room_members enable row level security;
alter table public.messages enable row level security;

create policy "members can read own room membership"
on public.room_members for select to authenticated
using (user_id = auth.uid());

create policy "members can leave room"
on public.room_members for delete to authenticated
using (user_id = auth.uid());

create policy "members can read messages"
on public.messages for select to authenticated
using (exists (
  select 1 from public.room_members m
  where m.room_id = messages.room_id and m.user_id = auth.uid()
));

create policy "members can send messages as themselves"
on public.messages for insert to authenticated
with check (
  author_id = auth.uid()
  and exists (
    select 1 from public.room_members m
    where m.room_id = messages.room_id and m.user_id = auth.uid()
  )
);

create or replace function public.create_room()
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_room uuid;
  v_code text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  v_code := encode(extensions.gen_random_bytes(8), 'hex');

  insert into public.chat_rooms(invite_hash, invite_used)
  values (extensions.digest(convert_to(v_code, 'utf8'), 'sha256'), false)
  returning id into v_room;

  insert into public.room_members(room_id, user_id)
  values (v_room, auth.uid());

  return jsonb_build_object('room_id', v_room, 'invite_code', v_code);
end;
$$;

create or replace function public.join_room(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_room uuid;
  v_used boolean;
  v_member_count int;
  v_clean_code text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  v_clean_code := lower(trim(coalesce(p_code, '')));
  if length(v_clean_code) <> 16 then
    raise exception 'Invalid invite code';
  end if;

  select id, invite_used
  into v_room, v_used
  from public.chat_rooms
  where invite_hash = extensions.digest(convert_to(v_clean_code, 'utf8'), 'sha256');

  if v_room is null or v_used then
    raise exception 'Invalid or already used invite code';
  end if;

  select count(*) into v_member_count
  from public.room_members
  where room_id = v_room;

  if v_member_count >= 2 then
    raise exception 'Room is already full';
  end if;

  insert into public.room_members(room_id, user_id)
  values (v_room, auth.uid())
  on conflict do nothing;

  update public.chat_rooms
  set invite_used = true
  where id = v_room;

  return jsonb_build_object('room_id', v_room);
end;
$$;

revoke all on function public.create_room() from public;
revoke all on function public.join_room(text) from public;
grant execute on function public.create_room() to authenticated;
grant execute on function public.join_room(text) to authenticated;

grant select, delete on public.room_members to authenticated;
grant select, insert on public.messages to authenticated;

alter publication supabase_realtime add table public.messages;
