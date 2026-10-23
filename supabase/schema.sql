-- =====================================================================
--  UMBIX · Fase 1 · Base de datos para Supabase
--  Cómo usarlo: Supabase → SQL Editor → New query → pega TODO → Run.
--  Se puede volver a ejecutar cuando haya una versión nueva: no borra datos.
-- =====================================================================

-- ---------------------------------------------------------------------
--  Tablas
-- ---------------------------------------------------------------------
create table if not exists public.profiles (
  id                uuid primary key references auth.users(id) on delete cascade,
  username          text not null unique check (username ~ '^[a-z0-9_.]{3,20}$'),
  display_name      text not null check (char_length(display_name) between 1 and 32),
  card              jsonb not null default '{}'::jsonb check (octet_length(card::text) < 60000),
  badges            text[] not null default '{early,beta}',
  is_admin          boolean not null default false,
  banned_at         timestamptz,
  ban_reason        text,
  accepted_terms_at timestamptz,
  last_seen         timestamptz not null default now(),
  created_at        timestamptz not null default now()
);

create table if not exists public.friend_requests (
  from_id    uuid not null references public.profiles(id) on delete cascade,
  to_id      uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (from_id, to_id),
  check (from_id <> to_id)
);
create index if not exists friend_requests_to_idx on public.friend_requests(to_id);

create table if not exists public.friendships (
  user_a     uuid not null references public.profiles(id) on delete cascade,
  user_b     uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_a, user_b),
  check (user_a < user_b)
);
create index if not exists friendships_b_idx on public.friendships(user_b);

create table if not exists public.blocks (
  blocker    uuid not null references public.profiles(id) on delete cascade,
  blocked    uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker, blocked),
  check (blocker <> blocked)
);

create table if not exists public.servers (
  id          uuid primary key default gen_random_uuid(),
  owner_id    uuid not null references public.profiles(id) on delete cascade,
  name        text not null check (char_length(name) between 1 and 60),
  color       text not null default '#8B7CF6',
  icon_url    text not null default '',
  banner      text not null default '',
  banner_url  text not null default '',
  description text not null default '' check (char_length(description) <= 600),
  tag         jsonb,
  settings    jsonb not null default '{}'::jsonb check (octet_length(settings::text) < 120000),
  created_at  timestamptz not null default now()
);

create table if not exists public.server_members (
  server_id uuid not null references public.servers(id) on delete cascade,
  user_id   uuid not null references public.profiles(id) on delete cascade,
  roles     text[] not null default '{}',
  joined_at timestamptz not null default now(),
  primary key (server_id, user_id)
);
create index if not exists server_members_user_idx on public.server_members(user_id);

create table if not exists public.server_bans (
  server_id  uuid not null references public.servers(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  reason     text not null default '',
  created_at timestamptz not null default now(),
  primary key (server_id, user_id)
);

create table if not exists public.server_invites (
  code       text primary key check (code ~ '^[A-Za-z0-9]{4,16}$'),
  server_id  uuid not null references public.servers(id) on delete cascade,
  created_by uuid references public.profiles(id) on delete set null,
  max_uses   int not null default 0 check (max_uses >= 0),
  uses       int not null default 0,
  expires_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists server_invites_server_idx on public.server_invites(server_id);

create table if not exists public.channels (
  id         uuid primary key default gen_random_uuid(),
  server_id  uuid not null references public.servers(id) on delete cascade,
  name       text not null check (char_length(name) between 1 and 100),
  type       text not null default 'text' check (type in ('text','announce','voice','stage','forum','media')),
  category   text not null default 'Canales de texto' check (char_length(category) <= 100),
  position   int not null default 0,
  settings   jsonb not null default '{}'::jsonb check (octet_length(settings::text) < 20000),
  created_at timestamptz not null default now()
);
create index if not exists channels_server_idx on public.channels(server_id);

create table if not exists public.messages (
  id         uuid primary key default gen_random_uuid(),
  channel_id uuid references public.channels(id) on delete cascade,
  dm_a       uuid references public.profiles(id) on delete cascade,
  dm_b       uuid references public.profiles(id) on delete cascade,
  author_id  uuid not null references public.profiles(id) on delete cascade,
  content    text not null default '' check (char_length(content) <= 2000),
  kind       text not null default 'text' check (kind in ('text','poll','dice','coin')),
  data       jsonb not null default '{}'::jsonb check (octet_length(data::text) < 8000),
  reply_to   uuid references public.messages(id) on delete set null,
  rev        int not null default 0,
  deleted    boolean not null default false,
  created_at timestamptz not null default now(),
  check ((channel_id is not null and dm_a is null and dm_b is null)
      or (channel_id is null and dm_a is not null and dm_b is not null and dm_a < dm_b))
);
create index if not exists messages_channel_idx on public.messages(channel_id, created_at desc);
create index if not exists messages_dm_idx      on public.messages(dm_a, dm_b, created_at desc);
create index if not exists messages_author_idx  on public.messages(author_id, created_at desc);

create table if not exists public.message_reactions (
  message_id uuid not null references public.messages(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  emoji      text not null check (char_length(emoji) between 1 and 32),
  created_at timestamptz not null default now(),
  primary key (message_id, user_id, emoji)
);

create table if not exists public.poll_votes (
  message_id uuid not null references public.messages(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  option     smallint not null check (option between 0 and 5),
  primary key (message_id, user_id)
);

create table if not exists public.reports (
  id               uuid primary key default gen_random_uuid(),
  reporter_id      uuid references public.profiles(id) on delete set null,
  target_user      uuid references public.profiles(id) on delete set null,
  message_id       uuid references public.messages(id) on delete set null,
  message_snapshot text not null default '',
  reason           text not null check (reason in ('spam','acoso','odio','sexual','violencia','menor','suplantacion','autolesion','otro')),
  details          text not null default '' check (char_length(details) <= 1000),
  status           text not null default 'open' check (status in ('open','dismissed','actioned')),
  resolved_by      uuid references public.profiles(id) on delete set null,
  resolved_at      timestamptz,
  created_at       timestamptz not null default now()
);
create index if not exists reports_status_idx on public.reports(status, created_at desc);

create table if not exists public.blocked_words (
  word       text primary key check (char_length(word) between 2 and 40),
  created_at timestamptz not null default now()
);

-- Avisos privados para que la app sepa que algo cambió (amigos, servidores…)
create table if not exists public.user_events (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  kind       text not null,
  data       jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists user_events_user_idx on public.user_events(user_id, created_at);

-- ---------------------------------------------------------------------
--  Funciones de ayuda
-- ---------------------------------------------------------------------
create or replace function public.active_uid() returns uuid
language plpgsql stable security definer set search_path = public as $$
declare v uuid := auth.uid(); b timestamptz;
begin
  if v is null then raise exception 'not_authenticated'; end if;
  select banned_at into b from profiles where id = v;
  if not found then raise exception 'no_profile'; end if;
  if b is not null then raise exception 'banned'; end if;
  return v;
end $$;

create or replace function public.is_member(p_server uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from server_members where server_id = p_server and user_id = auth.uid());
$$;

create or replace function public.is_server_admin(p_server uuid, p_user uuid default null) returns boolean
language sql stable security definer set search_path = public as $$
  with u as (select coalesce(p_user, auth.uid()) as id)
  select exists (select 1 from servers s, u where s.id = p_server and s.owner_id = u.id)
      or exists (
        select 1 from server_members m, u, servers s,
               jsonb_array_elements(case when jsonb_typeof(s.settings->'roles') = 'array' then s.settings->'roles' else '[]'::jsonb end) r
        where m.server_id = p_server and m.user_id = u.id and s.id = p_server
          and (r->>'id') = any (m.roles)
          and coalesce((r->'perms'->>'admin')::boolean, false));
$$;

-- Miembro del servidor y, si el canal es privado, con un rol permitido (o administrador)
create or replace function public.channel_member(p_channel uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from channels c join server_members m on m.server_id = c.server_id
                 where c.id = p_channel and m.user_id = auth.uid()
                   and (coalesce((c.settings->>'private')::boolean, false) = false
                        or public.is_server_admin(c.server_id)
                        or exists (select 1 from jsonb_array_elements_text(
                                     case when jsonb_typeof(c.settings->'roles') = 'array' then c.settings->'roles' else '[]'::jsonb end) r
                                   where r = any (m.roles))));
$$;

create or replace function public.can_see_message(p_message uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from messages m where m.id = p_message and (
    (m.channel_id is not null and public.channel_member(m.channel_id)) or
    (m.channel_id is null and auth.uid() in (m.dm_a, m.dm_b))));
$$;

create or replace function public.is_blocked(p_a uuid, p_b uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from blocks where (blocker = p_a and blocked = p_b) or (blocker = p_b and blocked = p_a));
$$;

create or replace function public.are_friends(p_a uuid, p_b uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from friendships where user_a = least(p_a, p_b) and user_b = greatest(p_a, p_b));
$$;

create or replace function public.notify(p_user uuid, p_kind text, p_data jsonb default '{}'::jsonb) returns void
language sql security definer set search_path = public as $$
  insert into user_events(user_id, kind, data) values (p_user, p_kind, coalesce(p_data, '{}'::jsonb));
$$;

create or replace function public.notify_server(p_server uuid, p_kind text default 'servers') returns void
language sql security definer set search_path = public as $$
  insert into user_events(user_id, kind, data)
  select user_id, p_kind, jsonb_build_object('server', p_server) from server_members where server_id = p_server;
$$;

create or replace function public.public_profile(p public.profiles) returns jsonb
language sql stable as $$
  select jsonb_build_object('id', p.id, 'username', p.username, 'display_name', p.display_name, 'card', p.card,
    'badges', to_jsonb(p.badges), 'last_seen', p.last_seen, 'created_at', p.created_at, 'banned', p.banned_at is not null);
$$;

create or replace function public.message_json(m public.messages) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', m.id, 'channel_id', m.channel_id, 'dm_a', m.dm_a, 'dm_b', m.dm_b, 'author_id', m.author_id,
    'content', case when m.deleted then '' else m.content end, 'kind', m.kind,
    'data', case when m.deleted then '{}'::jsonb else m.data end,
    'reply_to', m.reply_to, 'deleted', m.deleted, 'rev', m.rev, 'created_at', m.created_at,
    'reply', (select jsonb_build_object('author_id', r.author_id, 'kind', r.kind,
                'content', case when r.deleted then '' else left(case when r.kind = 'poll' then coalesce(r.data->>'q','') else r.content end, 120) end)
              from messages r where r.id = m.reply_to),
    'reacts', coalesce((select jsonb_agg(jsonb_build_object('emoji', x.emoji, 'users', x.users)) from (
                 select emoji, jsonb_agg(user_id order by created_at) users, min(created_at) first
                 from message_reactions where message_id = m.id group by emoji order by first) x), '[]'::jsonb),
    'votes', coalesce((select jsonb_agg(jsonb_build_object('user', user_id, 'option', option)) from poll_votes where message_id = m.id), '[]'::jsonb));
$$;

create or replace function public.server_json(p_server uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', s.id, 'owner_id', s.owner_id, 'name', s.name, 'color', s.color, 'icon_url', s.icon_url,
    'banner', s.banner, 'banner_url', s.banner_url, 'description', s.description, 'tag', s.tag,
    'settings', s.settings, 'created_at', s.created_at,
    'members', coalesce((select jsonb_agg(jsonb_build_object('id', m.user_id, 'roles', to_jsonb(m.roles)) order by m.joined_at)
                         from server_members m where m.server_id = s.id), '[]'::jsonb),
    'channels', coalesce((select jsonb_agg(jsonb_build_object('id', c.id, 'name', c.name, 'type', c.type, 'category', c.category,
                           'position', c.position, 'settings', c.settings) order by c.position, c.created_at)
                         from channels c where c.server_id = s.id), '[]'::jsonb),
    'invites', case when public.is_server_admin(s.id) then coalesce((select jsonb_agg(jsonb_build_object('code', i.code, 'uses', i.uses,
                  'max_uses', i.max_uses, 'expires_at', i.expires_at, 'created_at', i.created_at) order by i.created_at desc)
                  from server_invites i where i.server_id = s.id), '[]'::jsonb) else '[]'::jsonb end,
    'bans', case when public.is_server_admin(s.id) then coalesce((select jsonb_agg(jsonb_build_object('id', b.user_id, 'reason', b.reason,
                  'created_at', b.created_at)) from server_bans b where b.server_id = s.id), '[]'::jsonb) else '[]'::jsonb end)
  from servers s where s.id = p_server;
$$;

create or replace function public.clean_username(p text) returns text
language sql immutable as $$
  select left(regexp_replace(lower(coalesce(p, '')), '[^a-z0-9_.]', '', 'g'), 20);
$$;

-- ---------------------------------------------------------------------
--  Cuenta nueva → perfil
-- ---------------------------------------------------------------------
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare base text; uname text; n int := 0; meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
begin
  base := public.clean_username(meta->>'username');
  if char_length(base) < 3 then base := 'usuario'; end if;
  uname := base;
  while exists (select 1 from profiles where username = uname) loop
    n := n + 1;
    uname := left(base, 15) || (floor(random() * 90000) + 10000)::int::text;
    if n > 20 then uname := 'u' || substr(replace(new.id::text, '-', ''), 1, 12); exit; end if;
  end loop;
  insert into profiles(id, username, display_name, accepted_terms_at, card)
  values (new.id, uname,
          left(coalesce(nullif(trim(meta->>'display_name'), ''), uname), 32),
          case when (meta->>'accepted_terms') = 'true' then now() end,
          jsonb_build_object('color', coalesce(meta->>'color', '#8B7CF6'), 'status', 'online'))
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------
--  Lectura inicial
-- ---------------------------------------------------------------------
create or replace function public.username_available(p_username text) returns boolean
language sql stable security definer set search_path = public as $$
  select public.clean_username(p_username) = lower(p_username)
     and char_length(p_username) between 3 and 20
     and not exists (select 1 from profiles where username = lower(p_username));
$$;

create or replace function public.dm_streak(p_peer uuid, p_tz text default 'UTC') returns int
language plpgsql stable security definer set search_path = public as $$
declare v uuid := auth.uid(); d date; expect date; n int := 0; tz text;
begin
  begin
    expect := (now() at time zone p_tz)::date; tz := p_tz;
  exception when others then
    tz := 'UTC'; expect := (now() at time zone tz)::date;
  end;
  for d in select distinct (created_at at time zone tz)::date as day from messages
           where dm_a = least(v, p_peer) and dm_b = greatest(v, p_peer) and not deleted
             and created_at > now() - interval '400 days'
           order by day desc loop
    if n = 0 and d = expect - 1 then expect := d; end if;
    exit when d <> expect;
    n := n + 1; expect := expect - 1;
  end loop;
  return n;
end $$;

create or replace function public.bootstrap(p_tz text default 'UTC') returns jsonb
language plpgsql security definer set search_path = public as $$
declare v uuid := auth.uid(); me profiles; ids uuid[];
begin
  if v is null then raise exception 'not_authenticated'; end if;
  select * into me from profiles where id = v;
  if not found then raise exception 'no_profile'; end if;
  update profiles set last_seen = now() where id = v;
  select array_agg(distinct x) into ids from (
    select case when user_a = v then user_b else user_a end x from friendships where v in (user_a, user_b)
    union select case when from_id = v then to_id else from_id end from friend_requests where v in (from_id, to_id)
    union select m2.user_id from server_members m1 join server_members m2 on m2.server_id = m1.server_id where m1.user_id = v
    union select case when dm_a = v then dm_b else dm_a end from messages where v in (dm_a, dm_b)
    union select blocked from blocks where blocker = v
  ) t where x is not null and x <> v;
  return jsonb_build_object(
    'me', public.public_profile(me) || jsonb_build_object('email', (select email from auth.users where id = v),
            'is_admin', me.is_admin, 'banned_at', me.banned_at, 'ban_reason', me.ban_reason),
    'users', coalesce((select jsonb_agg(public.public_profile(p)) from profiles p where p.id = any (coalesce(ids, '{}'))), '[]'::jsonb),
    'friends', coalesce((select jsonb_agg(case when user_a = v then user_b else user_a end) from friendships where v in (user_a, user_b)), '[]'::jsonb),
    'requests', coalesce((select jsonb_agg(jsonb_build_object('id', case when from_id = v then to_id else from_id end,
                  'dir', case when from_id = v then 'out' else 'in' end) order by created_at) from friend_requests where v in (from_id, to_id)), '[]'::jsonb),
    'blocks', coalesce((select jsonb_agg(blocked) from blocks where blocker = v), '[]'::jsonb),
    'servers', coalesce((select jsonb_agg(public.server_json(m.server_id) order by m.joined_at) from server_members m where m.user_id = v), '[]'::jsonb),
    'dms', coalesce((select jsonb_agg(jsonb_build_object('peer', peer, 'last', last, 'streak', public.dm_streak(peer, p_tz)) order by last desc) from (
              select case when dm_a = v then dm_b else dm_a end peer, max(created_at) last
              from messages where v in (dm_a, dm_b) and not deleted group by 1) d), '[]'::jsonb),
    'server_time', now());
end $$;

create or replace function public.get_profiles(p_ids uuid[]) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(public.public_profile(p)), '[]'::jsonb) from profiles p
  where p.id = any (p_ids[1:300]) and auth.uid() is not null;
$$;

create or replace function public.heartbeat(p_status text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v uuid := auth.uid();
begin
  if v is null then raise exception 'not_authenticated'; end if;
  update profiles set last_seen = now(),
         card = case when p_status in ('online','idle','dnd','offline') then jsonb_set(card, '{status}', to_jsonb(p_status)) else card end
   where id = v;
  delete from user_events where user_id = v and created_at < now() - interval '2 days';
  return jsonb_build_object('server_time', now());
end $$;

-- ---------------------------------------------------------------------
--  Mensajes
-- ---------------------------------------------------------------------
create or replace function public.get_messages(p_channel uuid default null, p_peer uuid default null,
                                               p_before timestamptz default null, p_limit int default 50) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v uuid := auth.uid(); lim int := least(greatest(coalesce(p_limit, 50), 1), 100);
begin
  if v is null then raise exception 'not_authenticated'; end if;
  if p_channel is not null then
    if not public.channel_member(p_channel) then raise exception 'forbidden'; end if;
    return coalesce((select jsonb_agg(public.message_json(m) order by m.created_at) from (
      select * from messages where channel_id = p_channel and (p_before is null or created_at < p_before)
      order by created_at desc limit lim) m), '[]'::jsonb);
  elsif p_peer is not null then
    return coalesce((select jsonb_agg(public.message_json(m) order by m.created_at) from (
      select * from messages where dm_a = least(v, p_peer) and dm_b = greatest(v, p_peer)
        and (p_before is null or created_at < p_before)
      order by created_at desc limit lim) m), '[]'::jsonb);
  end if;
  raise exception 'bad_request';
end $$;

create or replace function public.get_message(p_id uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select public.message_json(m) from messages m where m.id = p_id and public.can_see_message(p_id);
$$;

create or replace function public.check_words(p_text text, p_extra jsonb default '[]'::jsonb) returns boolean
language sql stable security definer set search_path = public as $$
  select not exists (
    select 1 from (select word from blocked_words
                   union all select jsonb_array_elements_text(case when jsonb_typeof(p_extra) = 'array' then p_extra else '[]'::jsonb end)) w
    where char_length(trim(w.word)) >= 2
      and lower(p_text) ~ ('(^|[^[:alnum:]])' || regexp_replace(lower(trim(w.word)), '([.*+?^${}()|\[\]\\])', '\\\1', 'g') || '($|[^[:alnum:]])'));
$$;

create or replace function public.send_message(p_channel uuid default null, p_peer uuid default null, p_content text default '',
                                               p_kind text default 'text', p_data jsonb default '{}'::jsonb,
                                               p_reply_to uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v uuid := public.active_uid(); c channels; s servers; body text := trim(coalesce(p_content, ''));
        k text := coalesce(p_kind, 'text'); d jsonb := '{}'::jsonb; slow int; r messages; m messages;
        opts jsonb; q text;
begin
  if k not in ('text','poll','dice','coin') then raise exception 'bad_kind'; end if;
  if (select count(*) from messages where author_id = v and created_at > now() - interval '10 seconds') >= 8 then
    raise exception 'rate_limited';
  end if;
  if k = 'text' then
    if body = '' then raise exception 'empty'; end if;
    if char_length(body) > 2000 then raise exception 'too_long'; end if;
  elsif k = 'poll' then
    q := left(trim(coalesce(p_data->>'q', '')), 140);
    select jsonb_agg(left(trim(x), 60)) into opts from jsonb_array_elements_text(coalesce(p_data->'opts', '[]'::jsonb)) x where trim(x) <> '';
    if q = '' or opts is null or jsonb_array_length(opts) < 2 or jsonb_array_length(opts) > 6 then raise exception 'bad_poll'; end if;
    d := jsonb_build_object('q', q, 'opts', opts); body := '';
  elsif k = 'dice' then d := jsonb_build_object('v', 1 + floor(random() * 6)::int); body := '';
  else d := jsonb_build_object('v', case when random() < .5 then 'cara' else 'cruz' end); body := '';
  end if;
  if not public.check_words(body || ' ' || coalesce(d->>'q', '') || ' ' || coalesce(d->>'opts', '')) then raise exception 'blocked_word'; end if;

  if p_channel is not null then
    select * into c from channels where id = p_channel;
    if not found or not public.channel_member(c.id) then raise exception 'forbidden'; end if;
    select * into s from servers where id = c.server_id;
    if c.type not in ('text','announce') then raise exception 'channel_not_text'; end if;
    if c.type = 'announce' and not public.is_server_admin(s.id) then raise exception 'announce_only'; end if;
    if not public.is_server_admin(s.id) then
      slow := coalesce((c.settings->>'slow')::int, 0);
      if slow > 0 and exists (select 1 from messages where channel_id = c.id and author_id = v
                              and created_at > now() - make_interval(secs => slow)) then raise exception 'slow_mode'; end if;
      if not public.check_words(body || ' ' || coalesce(d->>'q', '') || ' ' || coalesce(d->>'opts', ''),
                                coalesce(s.settings->'automod'->'words', '[]'::jsonb)) then raise exception 'automod'; end if;
    end if;
    if p_reply_to is not null then
      select * into r from messages where id = p_reply_to and channel_id = c.id;
      if not found then p_reply_to := null; end if;
    end if;
    insert into messages(channel_id, author_id, content, kind, data, reply_to)
    values (c.id, v, body, k, d, p_reply_to) returning * into m;
  elsif p_peer is not null then
    if p_peer = v or not exists (select 1 from profiles where id = p_peer) then raise exception 'not_found'; end if;
    if public.is_blocked(v, p_peer) then raise exception 'blocked'; end if;
    if not public.are_friends(v, p_peer) and not exists (
         select 1 from server_members a join server_members b on a.server_id = b.server_id
         where a.user_id = v and b.user_id = p_peer) then raise exception 'not_friends'; end if;
    if p_reply_to is not null then
      select * into r from messages where id = p_reply_to and dm_a = least(v, p_peer) and dm_b = greatest(v, p_peer);
      if not found then p_reply_to := null; end if;
    end if;
    insert into messages(dm_a, dm_b, author_id, content, kind, data, reply_to)
    values (least(v, p_peer), greatest(v, p_peer), v, body, k, d, p_reply_to) returning * into m;
  else
    raise exception 'bad_request';
  end if;
  return public.message_json(m);
end $$;

create or replace function public.delete_message(p_id uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v uuid := public.active_uid(); m messages; sid uuid;
begin
  select * into m from messages where id = p_id;
  if not found then raise exception 'not_found'; end if;
  if m.author_id <> v then
    if m.channel_id is null then raise exception 'forbidden'; end if;
    select server_id into sid from channels where id = m.channel_id;
    if not public.is_server_admin(sid) then raise exception 'forbidden'; end if;
  end if;
  update messages set deleted = true, content = '', data = '{}'::jsonb, rev = rev + 1 where id = p_id returning * into m;
  delete from message_reactions where message_id = p_id;
  delete from poll_votes where message_id = p_id;
  return public.message_json(m);
end $$;

create or replace function public.toggle_reaction(p_id uuid, p_emoji text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v uuid := public.active_uid(); e text := trim(coalesce(p_emoji, '')); m messages;
begin
  if e = '' or char_length(e) > 32 or e ~ '[<>"''`&\\]' then raise exception 'bad_emoji'; end if;
  if not public.can_see_message(p_id) then raise exception 'forbidden'; end if;
  if exists (select 1 from message_reactions where message_id = p_id and user_id = v and emoji = e) then
    delete from message_reactions where message_id = p_id and user_id = v and emoji = e;
  else
    if (select count(distinct emoji) from message_reactions where message_id = p_id) >= 20
       and not exists (select 1 from message_reactions where message_id = p_id and emoji = e) then raise exception 'too_many_reactions'; end if;
    insert into message_reactions(message_id, user_id, emoji) values (p_id, v, e);
  end if;
  update messages set rev = rev + 1 where id = p_id returning * into m;
  return public.message_json(m);
end $$;

create or replace function public.vote_poll(p_id uuid, p_option int default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v uuid := public.active_uid(); m messages;
begin
  if not public.can_see_message(p_id) then raise exception 'forbidden'; end if;
  select * into m from messages where id = p_id;
  if m.kind <> 'poll' or m.deleted then raise exception 'not_poll'; end if;
  if p_option is null then
    delete from poll_votes where message_id = p_id and user_id = v;
  else
    if p_option < 0 or p_option >= jsonb_array_length(m.data->'opts') then raise exception 'bad_option'; end if;
    insert into poll_votes(message_id, user_id, option) values (p_id, v, p_option)
    on conflict (message_id, user_id) do update set option = excluded.option;
  end if;
  update messages set rev = rev + 1 where id = p_id returning * into m;
  return public.message_json(m);
end $$;

-- ---------------------------------------------------------------------
--  Amigos y bloqueos
-- ---------------------------------------------------------------------
create or replace function public.send_friend_request(p_username text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v uuid := public.active_uid(); t profiles;
begin
  select * into t from profiles where username = lower(trim(both '@ ' from coalesce(p_username, '')));
  if not found or t.banned_at is not null then return jsonb_build_object('status', 'not_found'); end if;
  if t.id = v then return jsonb_build_object('status', 'self'); end if;
  if public.is_blocked(v, t.id) then return jsonb_build_object('status', 'not_found'); end if;
  if public.are_friends(v, t.id) then return jsonb_build_object('status', 'already', 'user', public.public_profile(t)); end if;
  if exists (select 1 from friend_requests where from_id = t.id and to_id = v) then
    delete from friend_requests where from_id = t.id and to_id = v;
    insert into friendships(user_a, user_b) values (least(v, t.id), greatest(v, t.id)) on conflict do nothing;
    perform public.notify(t.id, 'friends');
    return jsonb_build_object('status', 'accepted', 'user', public.public_profile(t));
  end if;
  if exists (select 1 from friend_requests where from_id = v and to_id = t.id) then
    return jsonb_build_object('status', 'pending', 'user', public.public_profile(t));
  end if;
  if (select count(*) from friend_requests where from_id = v) >= 50 then raise exception 'too_many_requests'; end if;
  insert into friend_requests(from_id, to_id) values (v, t.id);
  perform public.notify(t.id, 'friends');
  return jsonb_build_object('status', 'sent', 'user', public.public_profile(t));
end $$;

create or replace function public.respond_friend_request(p_user uuid, p_accept boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v uuid := public.active_uid();
begin
  delete from friend_requests where from_id = p_user and to_id = v;
  if not found then return jsonb_build_object('status', 'not_found'); end if;
  if p_accept then
    insert into friendships(user_a, user_b) values (least(v, p_user), greatest(v, p_user)) on conflict do nothing;
  end if;
  perform public.notify(p_user, 'friends');
  return jsonb_build_object('status', case when p_accept then 'accepted' else 'declined' end);
end $$;

create or replace function public.cancel_friend_request(p_user uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v uuid := public.active_uid();
begin
  delete from friend_requests where from_id = v and to_id = p_user;
  perform public.notify(p_user, 'friends');
  return jsonb_build_object('status', 'ok');
end $$;

create or replace function public.remove_friend(p_user uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v uuid := public.active_uid();
begin
  delete from friendships where user_a = least(v, p_user) and user_b = greatest(v, p_user);
  perform public.notify(p_user, 'friends');
  return jsonb_build_object('status', 'ok');
end $$;

create or replace function public.block_user(p_user uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v uuid := public.active_uid();
begin
  if p_user = v or not exists (select 1 from profiles where id = p_user) then raise exception 'not_found'; end if;
  insert into blocks(blocker, blocked) values (v, p_user) on conflict do nothing;
  delete from friendships where user_a = least(v, p_user) and user_b = greatest(v, p_user);
  delete from friend_requests where (from_id = v and to_id = p_user) or (from_id = p_user and to_id = v);
  perform public.notify(p_user, 'friends');
  return jsonb_build_object('status', 'ok');
end $$;

create or replace function public.unblock_user(p_user uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v uuid := public.active_uid();
begin
  delete from blocks where blocker = v and blocked = p_user;
  return jsonb_build_object('status', 'ok');
end $$;

-- ---------------------------------------------------------------------
--  Perfil
-- ---------------------------------------------------------------------
create or replace function public.update_profile(p_display_name text default null, p_card jsonb default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v uuid := public.active_uid(); dn text := trim(coalesce(p_display_name, '')); p profiles;
begin
  if p_card is not null and jsonb_typeof(p_card) <> 'object' then raise exception 'bad_card'; end if;
  if p_card is not null and octet_length(p_card::text) >= 60000 then raise exception 'card_too_big'; end if;
  if dn <> '' and not public.check_words(dn) then raise exception 'blocked_word'; end if;
  update profiles set display_name = case when dn <> '' then left(dn, 32) else display_name end,
                      card = coalesce(p_card, card), last_seen = now()
   where id = v returning * into p;
  return public.public_profile(p);
end $$;

create or replace function public.change_username(p_username text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v uuid := public.active_uid(); u text := lower(trim(coalesce(p_username, '')));
begin
  if u !~ '^[a-z0-9_.]{3,20}$' then return jsonb_build_object('status', 'invalid'); end if;
  if not public.check_words(u) then return jsonb_build_object('status', 'invalid'); end if;
  if exists (select 1 from profiles where username = u and id <> v) then return jsonb_build_object('status', 'taken'); end if;
  update profiles set username = u where id = v;
  return jsonb_build_object('status', 'ok', 'username', u);
end $$;

create or replace function public.delete_account() returns void
language plpgsql security definer set search_path = public, auth as $$
declare v uuid := auth.uid();
begin
  if v is null then raise exception 'not_authenticated'; end if;
  insert into user_events(user_id, kind)
    select user_id, 'servers' from server_members where server_id in (select server_id from server_members where user_id = v) and user_id <> v;
  insert into user_events(user_id, kind)
    select case when user_a = v then user_b else user_a end, 'friends' from friendships where v in (user_a, user_b);
  delete from auth.users where id = v;
end $$;

-- ---------------------------------------------------------------------
--  Servidores y canales
-- ---------------------------------------------------------------------
create or replace function public.create_server(p jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v uuid := public.active_uid(); sid uuid; ch jsonb; cid uuid; keys jsonb := '{}'::jsonb; i int := 0; nm text := trim(coalesce(p->>'name', ''));
begin
  if nm = '' then raise exception 'bad_name'; end if;
  if not public.check_words(nm) then raise exception 'blocked_word'; end if;
  if (select count(*) from servers where owner_id = v) >= 25 then raise exception 'too_many_servers'; end if;
  if jsonb_array_length(coalesce(p->'channels', '[]'::jsonb)) > 60 then raise exception 'too_many_channels'; end if;
  insert into servers(owner_id, name, color, icon_url, banner, banner_url, description, tag, settings)
  values (v, left(nm, 60), coalesce(p->>'color', '#8B7CF6'), coalesce(p->>'icon_url', ''), coalesce(p->>'banner', ''),
          coalesce(p->>'banner_url', ''), left(coalesce(p->>'description', ''), 600),
          case when jsonb_typeof(p->'tag') = 'object' then p->'tag' end, coalesce(p->'settings', '{}'::jsonb))
  returning id into sid;
  insert into server_members(server_id, user_id) values (sid, v);
  for ch in select * from jsonb_array_elements(coalesce(p->'channels', '[]'::jsonb)) loop
    insert into channels(server_id, name, type, category, position, settings)
    values (sid, left(coalesce(nullif(trim(ch->>'name'), ''), 'general'), 100), coalesce(ch->>'type', 'text'),
            left(coalesce(ch->>'category', 'Canales de texto'), 100), i, coalesce(ch->'settings', '{}'::jsonb))
    returning id into cid;
    if ch ? 'key' then keys := keys || jsonb_build_object(ch->>'key', cid); end if;
    i := i + 1;
  end loop;
  return public.server_json(sid) || jsonb_build_object('channel_keys', keys);
end $$;

create or replace function public.update_server(p_id uuid, p jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v uuid := public.active_uid();
begin
  if not public.is_server_admin(p_id) then raise exception 'forbidden'; end if;
  if p ? 'name' and (trim(p->>'name') = '' or not public.check_words(p->>'name')) then raise exception 'bad_name'; end if;
  update servers set
    name        = case when p ? 'name' then left(trim(p->>'name'), 60) else name end,
    color       = case when p ? 'color' then coalesce(p->>'color', color) else color end,
    icon_url    = case when p ? 'icon_url' then coalesce(p->>'icon_url', '') else icon_url end,
    banner      = case when p ? 'banner' then coalesce(p->>'banner', '') else banner end,
    banner_url  = case when p ? 'banner_url' then coalesce(p->>'banner_url', '') else banner_url end,
    description = case when p ? 'description' then left(coalesce(p->>'description', ''), 600) else description end,
    tag         = case when p ? 'tag' then (case when jsonb_typeof(p->'tag') = 'object' then p->'tag' end) else tag end,
    settings    = case when p ? 'settings' and jsonb_typeof(p->'settings') = 'object' then p->'settings' else settings end
  where id = p_id;
  perform public.notify_server(p_id);
  return public.server_json(p_id);
end $$;

create or replace function public.delete_server(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v uuid := public.active_uid();
begin
  if not exists (select 1 from servers where id = p_id and owner_id = v) then raise exception 'forbidden'; end if;
  perform public.notify_server(p_id);
  delete from servers where id = p_id;
end $$;

create or replace function public.leave_server(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v uuid := public.active_uid();
begin
  if exists (select 1 from servers where id = p_id and owner_id = v) then raise exception 'owner_cannot_leave'; end if;
  delete from server_members where server_id = p_id and user_id = v;
  perform public.notify_server(p_id);
end $$;

create or replace function public.create_invite(p_server uuid, p_code text default null, p_max int default 0, p_expires timestamptz default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v uuid := public.active_uid(); c text := p_code; n int := 0;
begin
  if not public.is_server_admin(p_server) then raise exception 'forbidden'; end if;
  if (select count(*) from server_invites where server_id = p_server) >= 50 then raise exception 'too_many_invites'; end if;
  if c is null or c !~ '^[A-Za-z0-9]{4,16}$' or exists (select 1 from server_invites where code = c) then
    loop
      c := substr(md5(random()::text || clock_timestamp()::text), 1, 7);
      exit when not exists (select 1 from server_invites where code = c);
      n := n + 1; if n > 10 then raise exception 'try_again'; end if;
    end loop;
  end if;
  insert into server_invites(code, server_id, created_by, max_uses, expires_at)
  values (c, p_server, v, greatest(coalesce(p_max, 0), 0), p_expires);
  return jsonb_build_object('code', c);
end $$;

create or replace function public.delete_invite(p_code text) returns void
language plpgsql security definer set search_path = public as $$
declare sid uuid;
begin
  perform public.active_uid();
  select server_id into sid from server_invites where code = p_code;
  if sid is null then return; end if;
  if not public.is_server_admin(sid) then raise exception 'forbidden'; end if;
  delete from server_invites where code = p_code;
end $$;

create or replace function public.join_server(p_code text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v uuid := public.active_uid(); i server_invites; v_code text := trim(regexp_replace(coalesce(p_code, ''), '^.*/', ''));
begin
  select * into i from server_invites where server_invites.code = v_code for update;
  if not found or (i.expires_at is not null and i.expires_at < now()) or (i.max_uses > 0 and i.uses >= i.max_uses) then
    return jsonb_build_object('status', 'invalid');
  end if;
  if exists (select 1 from server_bans where server_id = i.server_id and user_id = v) then return jsonb_build_object('status', 'banned'); end if;
  if exists (select 1 from server_members where server_id = i.server_id and user_id = v) then
    return jsonb_build_object('status', 'already', 'server', public.server_json(i.server_id));
  end if;
  if (select count(*) from server_members where user_id = v) >= 100 then raise exception 'too_many_servers'; end if;
  insert into server_members(server_id, user_id) values (i.server_id, v);
  update server_invites set uses = uses + 1 where server_invites.code = i.code;
  perform public.notify_server(i.server_id);
  return jsonb_build_object('status', 'joined', 'server', public.server_json(i.server_id));
end $$;

create or replace function public.create_channel(p_server uuid, p jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v uuid := public.active_uid(); c channels;
begin
  if not public.is_server_admin(p_server) then raise exception 'forbidden'; end if;
  if (select count(*) from channels where server_id = p_server) >= 200 then raise exception 'too_many_channels'; end if;
  insert into channels(server_id, name, type, category, position, settings)
  values (p_server, left(coalesce(nullif(trim(p->>'name'), ''), 'nuevo-canal'), 100), coalesce(p->>'type', 'text'),
          left(coalesce(p->>'category', 'Canales de texto'), 100),
          coalesce((p->>'position')::int, (select coalesce(max(position), 0) + 1 from channels where server_id = p_server)),
          coalesce(p->'settings', '{}'::jsonb))
  returning * into c;
  perform public.notify_server(p_server);
  return jsonb_build_object('id', c.id, 'name', c.name, 'type', c.type, 'category', c.category, 'position', c.position, 'settings', c.settings);
end $$;

create or replace function public.update_channel(p_id uuid, p jsonb) returns void
language plpgsql security definer set search_path = public as $$
declare sid uuid;
begin
  perform public.active_uid();
  select server_id into sid from channels where id = p_id;
  if sid is null or not public.is_server_admin(sid) then raise exception 'forbidden'; end if;
  update channels set
    name     = case when p ? 'name' then left(coalesce(nullif(trim(p->>'name'), ''), name), 100) else name end,
    category = case when p ? 'category' then left(coalesce(p->>'category', category), 100) else category end,
    position = case when p ? 'position' then coalesce((p->>'position')::int, position) else position end,
    settings = case when p ? 'settings' and jsonb_typeof(p->'settings') = 'object' then p->'settings' else settings end
  where id = p_id;
  perform public.notify_server(sid);
end $$;

create or replace function public.delete_channel(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare sid uuid;
begin
  perform public.active_uid();
  select server_id into sid from channels where id = p_id;
  if sid is null then return; end if;
  if not public.is_server_admin(sid) then raise exception 'forbidden'; end if;
  delete from channels where id = p_id;
  perform public.notify_server(sid);
end $$;

create or replace function public.set_member_roles(p_server uuid, p_user uuid, p_roles text[]) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public.active_uid();
  if not public.is_server_admin(p_server) then raise exception 'forbidden'; end if;
  update server_members set roles = coalesce(p_roles[1:30], '{}') where server_id = p_server and user_id = p_user;
  perform public.notify_server(p_server);
end $$;

create or replace function public.kick_member(p_server uuid, p_user uuid, p_ban boolean default false, p_reason text default '') returns void
language plpgsql security definer set search_path = public as $$
declare v uuid := public.active_uid();
begin
  if not public.is_server_admin(p_server) then raise exception 'forbidden'; end if;
  if p_user = v or exists (select 1 from servers where id = p_server and owner_id = p_user) then raise exception 'forbidden'; end if;
  if public.is_server_admin(p_server, p_user) and not exists (select 1 from servers where id = p_server and owner_id = v) then
    raise exception 'forbidden';
  end if;
  perform public.notify_server(p_server);
  delete from server_members where server_id = p_server and user_id = p_user;
  if p_ban then
    insert into server_bans(server_id, user_id, reason) values (p_server, p_user, left(coalesce(p_reason, ''), 300))
    on conflict (server_id, user_id) do update set reason = excluded.reason;
  end if;
end $$;

create or replace function public.unban_member(p_server uuid, p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public.active_uid();
  if not public.is_server_admin(p_server) then raise exception 'forbidden'; end if;
  delete from server_bans where server_id = p_server and user_id = p_user;
end $$;

-- ---------------------------------------------------------------------
--  Moderación
-- ---------------------------------------------------------------------
create or replace function public.report_content(p_user uuid default null, p_message uuid default null,
                                                 p_reason text default 'otro', p_details text default '') returns jsonb
language plpgsql security definer set search_path = public as $$
declare v uuid := auth.uid(); m messages; target uuid := p_user;
begin
  if v is null then raise exception 'not_authenticated'; end if;
  if (select count(*) from reports where reporter_id = v and created_at > now() - interval '1 day') >= 30 then raise exception 'rate_limited'; end if;
  if p_message is not null then
    if not public.can_see_message(p_message) then raise exception 'forbidden'; end if;
    select * into m from messages where id = p_message;
    target := m.author_id;
  end if;
  if target is null then raise exception 'bad_request'; end if;
  insert into reports(reporter_id, target_user, message_id, message_snapshot, reason, details)
  values (v, target, p_message,
          case when m.id is null then '' when m.kind = 'poll' then coalesce(m.data->>'q', '') else left(m.content, 2000) end,
          coalesce(p_reason, 'otro'), left(coalesce(p_details, ''), 1000));
  return jsonb_build_object('status', 'ok');
end $$;

create or replace function public.require_admin() returns uuid
language plpgsql stable security definer set search_path = public as $$
declare v uuid := auth.uid();
begin
  if v is null or not exists (select 1 from profiles where id = v and is_admin) then raise exception 'forbidden'; end if;
  return v;
end $$;

create or replace function public.admin_reports(p_status text default 'open') returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.require_admin();
  return coalesce((select jsonb_agg(jsonb_build_object(
      'id', r.id, 'reason', r.reason, 'details', r.details, 'status', r.status, 'created_at', r.created_at,
      'message_id', r.message_id, 'snapshot', r.message_snapshot,
      'message_deleted', coalesce((select deleted from messages where id = r.message_id), true),
      'reporter', (select jsonb_build_object('id', p.id, 'username', p.username, 'display_name', p.display_name) from profiles p where p.id = r.reporter_id),
      'target', (select jsonb_build_object('id', p.id, 'username', p.username, 'display_name', p.display_name, 'banned', p.banned_at is not null)
                 from profiles p where p.id = r.target_user),
      'target_reports', (select count(*) from reports r2 where r2.target_user = r.target_user)) order by r.created_at desc)
    from (select * from reports where status = coalesce(p_status, 'open') order by created_at desc limit 200) r), '[]'::jsonb);
end $$;

create or replace function public.admin_resolve(p_report uuid, p_action text, p_reason text default '') returns void
language plpgsql security definer set search_path = public as $$
declare a uuid := public.require_admin(); r reports;
begin
  select * into r from reports where id = p_report;
  if not found then raise exception 'not_found'; end if;
  if p_action = 'delete_message' and r.message_id is not null then
    update messages set deleted = true, content = '', data = '{}'::jsonb, rev = rev + 1 where id = r.message_id;
  elsif p_action = 'ban_user' and r.target_user is not null then
    update profiles set banned_at = now(), ban_reason = left(coalesce(nullif(p_reason, ''), r.reason), 300)
     where id = r.target_user and not is_admin;
    if r.message_id is not null then
      update messages set deleted = true, content = '', data = '{}'::jsonb, rev = rev + 1 where id = r.message_id;
    end if;
  elsif p_action <> 'dismiss' then raise exception 'bad_action';
  end if;
  update reports set status = case when p_action = 'dismiss' then 'dismissed' else 'actioned' end, resolved_by = a, resolved_at = now()
   where id = p_report or (p_action = 'ban_user' and target_user = r.target_user and status = 'open');
end $$;

create or replace function public.admin_unban(p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public.require_admin();
  update profiles set banned_at = null, ban_reason = null where id = p_user;
end $$;

create or replace function public.admin_words(p_add text default null, p_remove text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform public.require_admin();
  if nullif(trim(p_add), '') is not null then insert into blocked_words(word) values (lower(trim(p_add))) on conflict do nothing; end if;
  if p_remove is not null then delete from blocked_words where word = lower(trim(p_remove)); end if;
  return coalesce((select jsonb_agg(word order by word) from blocked_words), '[]'::jsonb);
end $$;

-- ---------------------------------------------------------------------
--  Seguridad por filas (RLS)
-- ---------------------------------------------------------------------
alter table public.profiles          enable row level security;
alter table public.friend_requests   enable row level security;
alter table public.friendships       enable row level security;
alter table public.blocks            enable row level security;
alter table public.servers           enable row level security;
alter table public.server_members    enable row level security;
alter table public.server_bans       enable row level security;
alter table public.server_invites    enable row level security;
alter table public.channels          enable row level security;
alter table public.messages          enable row level security;
alter table public.message_reactions enable row level security;
alter table public.poll_votes        enable row level security;
alter table public.reports           enable row level security;
alter table public.blocked_words     enable row level security;
alter table public.user_events       enable row level security;

drop policy if exists profiles_read on public.profiles;
create policy profiles_read on public.profiles for select to authenticated using (true);
drop policy if exists requests_read on public.friend_requests;
create policy requests_read on public.friend_requests for select to authenticated using (auth.uid() in (from_id, to_id));
drop policy if exists friendships_read on public.friendships;
create policy friendships_read on public.friendships for select to authenticated using (auth.uid() in (user_a, user_b));
drop policy if exists blocks_read on public.blocks;
create policy blocks_read on public.blocks for select to authenticated using (blocker = auth.uid());
drop policy if exists servers_read on public.servers;
create policy servers_read on public.servers for select to authenticated using (public.is_member(id));
drop policy if exists members_read on public.server_members;
create policy members_read on public.server_members for select to authenticated using (public.is_member(server_id));
drop policy if exists channels_read on public.channels;
create policy channels_read on public.channels for select to authenticated using (public.is_member(server_id));
drop policy if exists messages_read on public.messages;
create policy messages_read on public.messages for select to authenticated using (
  case when channel_id is not null then public.channel_member(channel_id) else auth.uid() in (dm_a, dm_b) end);
drop policy if exists reactions_read on public.message_reactions;
create policy reactions_read on public.message_reactions for select to authenticated using (public.can_see_message(message_id));
drop policy if exists votes_read on public.poll_votes;
create policy votes_read on public.poll_votes for select to authenticated using (public.can_see_message(message_id));
drop policy if exists events_read on public.user_events;
create policy events_read on public.user_events for select to authenticated using (user_id = auth.uid());
-- server_bans, server_invites, reports y blocked_words no tienen lectura directa: solo por funciones.

-- Nadie escribe directo en las tablas: todo pasa por las funciones de arriba, que revisan permisos.
revoke insert, update, delete, truncate on all tables in schema public from anon, authenticated;
revoke all on all tables in schema public from anon;
grant select on all tables in schema public to authenticated;
-- De los perfiles solo se pueden leer los datos públicos (no correo, ni motivos de suspensión, ni si alguien es admin)
revoke select on public.profiles from authenticated;
grant select (id, username, display_name, card, badges, last_seen, created_at) on public.profiles to authenticated;

revoke execute on all functions in schema public from public, anon;
grant execute on all functions in schema public to authenticated;
grant execute on function public.username_available(text) to anon;
revoke execute on function public.handle_new_user() from authenticated;
revoke execute on function public.notify(uuid, text, jsonb) from authenticated;
revoke execute on function public.notify_server(uuid, text) from authenticated;
revoke execute on function public.message_json(public.messages) from authenticated;
revoke execute on function public.server_json(uuid) from authenticated;
revoke execute on function public.public_profile(public.profiles) from authenticated;

-- ---------------------------------------------------------------------
--  Tiempo real
-- ---------------------------------------------------------------------
do $$
declare t text;
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
  foreach t in array array['messages','user_events'] loop
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------
--  Fotos (avatar, banner, íconos de servidor)
-- ---------------------------------------------------------------------
do $$
begin
  if exists (select 1 from information_schema.tables where table_schema = 'storage' and table_name = 'buckets') then
    insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    values ('media', 'media', true, 5242880, array['image/png','image/jpeg','image/webp','image/gif'])
    on conflict (id) do update set public = true, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

    execute 'drop policy if exists media_insert_own on storage.objects';
    execute $p$create policy media_insert_own on storage.objects for insert to authenticated
             with check (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text)$p$;
    execute 'drop policy if exists media_update_own on storage.objects';
    execute $p$create policy media_update_own on storage.objects for update to authenticated
             using (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text)$p$;
    execute 'drop policy if exists media_delete_own on storage.objects';
    execute $p$create policy media_delete_own on storage.objects for delete to authenticated
             using (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text)$p$;
    execute 'drop policy if exists media_list_own on storage.objects';
    execute $p$create policy media_list_own on storage.objects for select to authenticated
             using (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text)$p$;
  end if;
end $$;

-- Listo. Para volverte administrador (ver reportes), en Table Editor → profiles,
-- busca tu usuario y cambia is_admin a true.
