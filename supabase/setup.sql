-- life log: friends
-- Paste this whole file into Supabase → SQL Editor → New query, and press Run.
-- Safe to run again.
--
-- Only pet info is shared (name, animal, colour, stage, level, stats) plus how
-- many books/films you've finished (numbers only, never titles). Books, notes,
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
-- One shared plant per pair of friends (a < b). It grows one step on each day both water it.
create table if not exists public.plants (
  a       text not null references public.pets(code) on delete cascade,
  b       text not null references public.pets(code) on delete cascade,
  stage   int  not null default 0,
  water_a date,
  water_b date,
  grew_on date,
  primary key (a, b)
);

alter table public.pets add column if not exists species text;
alter table public.pets add column if not exists home jsonb;

create index if not exists gifts_inbox on public.gifts (to_code) where not seen;

-- Lock the tables: no policies means no direct access from the app.
alter table public.pets    enable row level security;
alter table public.friends enable row level security;
alter table public.gifts   enable row level security;
alter table public.plants  enable row level security;
revoke all on public.pets, public.friends, public.gifts, public.plants from anon, authenticated;

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
      species = left(p_pet->>'species', 8),
      home = case when length((p_pet->'home')::text) < 3000 then p_pet->'home' end,
      stage = (p_pet->>'stage')::int, level = (p_pet->>'level')::int, xp = (p_pet->>'xp')::int,
      stats = p_pet->'stats', mood = left(p_pet->>'mood', 12), updated_at = now()
    where code = p_code;
  else
    insert into pets (code, secret_hash, name, color, species, home, stage, level, xp, stats, mood)
    values (p_code, encode(digest(p_secret, 'sha256'), 'hex'),
      left(p_pet->>'name', 16), left(p_pet->>'color', 12), left(p_pet->>'species', 8),
      case when length((p_pet->'home')::text) < 3000 then p_pet->'home' end,
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
  if f.code is null then raise exception 'no pet with that code'; end if;
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

-- My friends' pets (with our shared plant).
drop function if exists public.get_friends(text, text);
create function public.get_friends(p_code text, p_secret text)
returns table (code text, name text, species text, color text, stage int, level int, xp int,
               stats jsonb, mood text, home jsonb, updated_at timestamptz, plant jsonb)
language sql stable security definer
set search_path = public, extensions as $$
  select p.code, p.name, p.species, p.color, p.stage, p.level, p.xp, p.stats, p.mood, p.home, p.updated_at,
    jsonb_build_object('stage', coalesce(pl.stage, 0),
      'mine', case when p_code < p.code then pl.water_a else pl.water_b end,
      'hers', case when p_code < p.code then pl.water_b else pl.water_a end)
  from friends f
  join pets p on p.code = f.b
  left join plants pl on pl.a = least(p_code, p.code) and pl.b = greatest(p_code, p.code)
  where f.a = p_code and _ll_auth(p_code, p_secret)
  order by p.name;
$$;

-- Water our shared plant (once a day each). Grows when both of us watered on the same day.
create or replace function public.water_plant(p_code text, p_secret text, p_friend text, p_day date)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare
  x text := least(p_code, p_friend);
  y text := greatest(p_code, p_friend);
  pl plants;
  grew boolean := false;
  already boolean := false;
begin
  if not _ll_auth(p_code, p_secret) then raise exception 'not allowed'; end if;
  if not exists (select 1 from friends where a = p_code and b = p_friend) then
    raise exception 'not friends yet';
  end if;
  if p_day is null or abs(p_day - current_date) > 1 then raise exception 'bad day'; end if;
  insert into plants (a, b) values (x, y) on conflict do nothing;
  select * into pl from plants where a = x and b = y for update;
  if (p_code = x and pl.water_a = p_day) or (p_code = y and pl.water_b = p_day) then
    already := true;
  else
    if p_code = x then pl.water_a := p_day; else pl.water_b := p_day; end if;
    if pl.water_a = p_day and pl.water_b = p_day and pl.grew_on is distinct from p_day and pl.stage < 6 then
      pl.stage := pl.stage + 1; pl.grew_on := p_day; grew := true;
    end if;
    update plants set water_a = pl.water_a, water_b = pl.water_b, stage = pl.stage, grew_on = pl.grew_on
    where a = x and b = y;
  end if;
  return jsonb_build_object('stage', pl.stage, 'grew', grew, 'already', already,
    'mine', case when p_code = x then pl.water_a else pl.water_b end,
    'hers', case when p_code = x then pl.water_b else pl.water_a end);
end $$;

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
  public.get_gifts(text, text), public.water_plant(text, text, text, date) from public;
grant execute on function public.save_pet(text, text, jsonb),
  public.add_friend(text, text, text), public.remove_friend(text, text, text),
  public.get_friends(text, text), public.send_gift(text, text, text, text),
  public.get_gifts(text, text), public.water_plant(text, text, text, date) to anon, authenticated;
