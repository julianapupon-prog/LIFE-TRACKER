-- life log: friends
-- Paste this whole file into Supabase → SQL Editor → New query, and press Run.
-- Safe to run again.
--
-- Only pet info is shared (name, colour, stage, level, stats). Books, notes,
-- workouts and everything else stay on your device.
-- The tables can't be read directly: the app only talks to the functions below,
-- and each one checks your secret (kept on your device and in your backups).

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.pets (
  code        text primary key,
  secret_hash text not null,
  name        text,
  color       text,
  stage       int,
  level       int,
  xp          int,
  stats       jsonb,
  mood        text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table if not exists public.friends (
  a          text not null references public.pets(code) on delete cascade,
  b          text not null references public.pets(code) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (a, b)
);

create table if not exists public.gifts (
  id         bigint generated always as identity primary key,
  from_code  text not null references public.pets(code) on delete cascade,
  to_code    text not null references public.pets(code) on delete cascade,
  kind       text not null,
  created_at timestamptz not null default now(),
  seen       boolean not null default false
);
create index if not exists gifts_inbox on public.gifts (to_code) where not seen;

-- Lock the tables: no policies means no direct access from the app.
alter table public.pets    enable row level security;
alter table public.friends enable row level security;
alter table public.gifts   enable row level security;
revoke all on public.pets, public.friends, public.gifts from anon, authenticated;

create or replace function public._ll_auth(p_code text, p_secret text)
returns boolean language sql stable security definer
set search_path = public, extensions as $$
  select exists (
    select 1 from pets
    where code = p_code
      and secret_hash = encode(digest(coalesce(p_secret, ''), 'sha256'), 'hex')
  );
$$;

-- Create or update my pet.
create or replace function public.save_pet(p_code text, p_secret text, p_pet jsonb)
returns void language plpgsql security definer
set search_path = public, extensions as $$
begin
  if p_code !~ '^LL-[A-Z0-9]{5}$' or length(coalesce(p_secret, '')) < 32 then
    raise exception 'bad code';
  end if;
  if exists (select 1 from pets where code = p_code) then
    if not _ll_auth(p_code, p_secret) then raise exception 'not allowed'; end if;
    update pets set
      name = left(p_pet->>'name', 16), color = left(p_pet->>'color', 12),
      stage = (p_pet->>'stage')::int, level = (p_pet->>'level')::int, xp = (p_pet->>'xp')::int,
      stats = p_pet->'stats', mood = left(p_pet->>'mood', 12), updated_at = now()
    where code = p_code;
  else
    insert into pets (code, secret_hash, name, color, stage, level, xp, stats, mood)
    values (p_code, encode(digest(p_secret, 'sha256'), 'hex'),
      left(p_pet->>'name', 16), left(p_pet->>'color', 12),
      (p_pet->>'stage')::int, (p_pet->>'level')::int, (p_pet->>'xp')::int,
      p_pet->'stats', left(p_pet->>'mood', 12));
  end if;
end $$;

-- Become friends using the other person's code (works both ways).
create or replace function public.add_friend(p_code text, p_secret text, p_friend text)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare f pets;
begin
  if not _ll_auth(p_code, p_secret) then raise exception 'not allowed'; end if;
  select * into f from pets where pets.code = upper(trim(p_friend));
  if f.code is null then raise exception 'no bunny with that code'; end if;
  if f.code = p_code then raise exception 'that''s your own code'; end if;
  insert into friends (a, b) values (p_code, f.code), (f.code, p_code) on conflict do nothing;
  return jsonb_build_object('code', f.code, 'name', f.name);
end $$;

create or replace function public.remove_friend(p_code text, p_secret text, p_friend text)
returns void language plpgsql security definer
set search_path = public, extensions as $$
begin
  if not _ll_auth(p_code, p_secret) then raise exception 'not allowed'; end if;
  delete from friends where (a = p_code and b = p_friend) or (a = p_friend and b = p_code);
end $$;

-- My friends' pets.
create or replace function public.get_friends(p_code text, p_secret text)
returns table (code text, name text, color text, stage int, level int, xp int,
               stats jsonb, mood text, updated_at timestamptz)
language sql stable security definer
set search_path = public, extensions as $$
  select p.code, p.name, p.color, p.stage, p.level, p.xp, p.stats, p.mood, p.updated_at
  from friends f join pets p on p.code = f.b
  where f.a = p_code and _ll_auth(p_code, p_secret)
  order by p.name;
$$;

-- Send a friend a heart, carrot or flower (max 10 a day to the same friend).
create or replace function public.send_gift(p_code text, p_secret text, p_to text, p_kind text)
returns void language plpgsql security definer
set search_path = public, extensions as $$
begin
  if not _ll_auth(p_code, p_secret) then raise exception 'not allowed'; end if;
  if p_kind not in ('heart', 'carrot', 'flower') then raise exception 'bad gift'; end if;
  if not exists (select 1 from friends where a = p_code and b = p_to) then
    raise exception 'not friends yet';
  end if;
  if (select count(*) from gifts where from_code = p_code and to_code = p_to
      and created_at > now() - interval '1 day') >= 10 then
    raise exception 'that''s a lot of gifts today! try tomorrow';
  end if;
  insert into gifts (from_code, to_code, kind) values (p_code, p_to, p_kind);
end $$;

-- Gifts I haven't seen yet (marks them as seen).
create or replace function public.get_gifts(p_code text, p_secret text)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare r jsonb;
begin
  if not _ll_auth(p_code, p_secret) then return '[]'::jsonb; end if;
  with g as (
    update gifts set seen = true where to_code = p_code and not seen
    returning from_code, kind, created_at
  )
  select coalesce(jsonb_agg(jsonb_build_object('from', g.from_code, 'name', p.name,
           'kind', g.kind, 'at', g.created_at) order by g.created_at), '[]'::jsonb)
  into r from g left join pets p on p.code = g.from_code;
  return r;
end $$;

revoke all on function public._ll_auth(text, text) from public, anon, authenticated;
revoke all on function public.save_pet(text, text, jsonb),
  public.add_friend(text, text, text), public.remove_friend(text, text, text),
  public.get_friends(text, text), public.send_gift(text, text, text, text),
  public.get_gifts(text, text) from public;
grant execute on function public.save_pet(text, text, jsonb),
  public.add_friend(text, text, text), public.remove_friend(text, text, text),
  public.get_friends(text, text), public.send_gift(text, text, text, text),
  public.get_gifts(text, text) to anon, authenticated;
