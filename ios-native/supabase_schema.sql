-- ============================================
-- Snaps Golf App - Supabase Schema
-- Run this in your Supabase SQL editor
-- ============================================

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ─── Profiles ────────────────────────────────────────────────────────────────
-- One profile per authenticated user
create table if not exists public.profiles (
  id          uuid references auth.users on delete cascade primary key,
  username    text unique not null,
  display_name text not null,
  avatar_url  text,
  venmo_handle text default '',
  cashapp_handle text default '',
  handicap    int default 0,
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);

-- Enable RLS
alter table public.profiles enable row level security;
create policy "Profiles are viewable by everyone" on public.profiles for select using (true);
create policy "Users can update own profile" on public.profiles for update using (auth.uid() = id);
create policy "Users can insert own profile" on public.profiles for insert with check (auth.uid() = id);

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, username, display_name, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    new.raw_user_meta_data->>'avatar_url'
  );
  return new;
end;
$$ language plpgsql security definer;

create or replace trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ─── Courses ─────────────────────────────────────────────────────────────────
create table if not exists public.courses (
  id          uuid default uuid_generate_v4() primary key,
  name        text not null,
  city        text,
  state       text,
  country     text default 'US',
  holes       jsonb not null default '[]',  -- [{hole:1, par:4, yardage:380, handicap:7}]
  location    point,  -- lat/lng for map
  created_at  timestamptz default now()
);

alter table public.courses enable row level security;
create policy "Courses are viewable by everyone" on public.courses for select using (true);

-- ─── Game Sessions ────────────────────────────────────────────────────────────
create table if not exists public.game_sessions (
  id          uuid default uuid_generate_v4() primary key,
  join_code   text unique not null default upper(substr(md5(random()::text), 1, 6)),
  host_id     uuid references public.profiles(id) not null,
  course_id   uuid references public.courses(id),
  course_name text,  -- fallback if no course selected
  pars        int[] default array_fill(4, array[18]),
  game_modes  jsonb not null default '[]',  -- [{mode, config}]
  status      text default 'waiting' check (status in ('waiting','active','complete')),
  vegas_team_a text[] default '{}',
  vegas_team_b text[] default '{}',
  created_at  timestamptz default now(),
  started_at  timestamptz,
  completed_at timestamptz
);

alter table public.game_sessions enable row level security;
create policy "Sessions viewable by participants" on public.game_sessions
  for select using (
    host_id = auth.uid() or
    exists (
      select 1 from public.session_players sp
      where sp.session_id = id and sp.user_id = auth.uid()
    )
  );
create policy "Host can update session" on public.game_sessions
  for update using (host_id = auth.uid());
create policy "Anyone can insert session" on public.game_sessions
  for insert with check (host_id = auth.uid());

-- ─── Session Players ──────────────────────────────────────────────────────────
create table if not exists public.session_players (
  id          uuid default uuid_generate_v4() primary key,
  session_id  uuid references public.game_sessions(id) on delete cascade not null,
  user_id     uuid references public.profiles(id) not null,
  display_name text not null,
  taxman      int default 90,
  joined_at   timestamptz default now(),
  unique(session_id, user_id)
);

alter table public.session_players enable row level security;
create policy "Players viewable by session participants" on public.session_players
  for select using (
    user_id = auth.uid() or
    exists (
      select 1 from public.game_sessions gs
      where gs.id = session_id and gs.host_id = auth.uid()
    ) or
    exists (
      select 1 from public.session_players sp2
      where sp2.session_id = session_id and sp2.user_id = auth.uid()
    )
  );
create policy "Users can join session" on public.session_players
  for insert with check (user_id = auth.uid());

-- ─── Scores ──────────────────────────────────────────────────────────────────
-- Each player's scores, updated in real-time as they play
create table if not exists public.scores (
  id          uuid default uuid_generate_v4() primary key,
  session_id  uuid references public.game_sessions(id) on delete cascade not null,
  user_id     uuid references public.profiles(id) not null,
  hole_scores int[] default array_fill(null::int, array[18]),  -- null = not yet scored
  updated_at  timestamptz default now(),
  unique(session_id, user_id)
);

alter table public.scores enable row level security;
create policy "Scores viewable by session participants" on public.scores
  for select using (
    exists (
      select 1 from public.session_players sp
      where sp.session_id = session_id and sp.user_id = auth.uid()
    ) or
    exists (
      select 1 from public.game_sessions gs
      where gs.id = session_id and gs.host_id = auth.uid()
    )
  );
create policy "Users update own scores" on public.scores
  for update using (user_id = auth.uid());
create policy "Users insert own scores" on public.scores
  for insert with check (user_id = auth.uid());

-- ─── Hole States ─────────────────────────────────────────────────────────────
-- Manual per-hole game tracking (Wolf, BBB, Snake, etc.)
create table if not exists public.hole_states (
  id          uuid default uuid_generate_v4() primary key,
  session_id  uuid references public.game_sessions(id) on delete cascade not null,
  hole        int not null check (hole between 0 and 17),
  state_data  jsonb not null default '{}',  -- wolf:{wolfId, partnerId}, bbb:{...}, etc.
  updated_by  uuid references public.profiles(id),
  updated_at  timestamptz default now(),
  unique(session_id, hole)
);

alter table public.hole_states enable row level security;
create policy "Hole states viewable by participants" on public.hole_states
  for select using (
    exists (
      select 1 from public.session_players sp
      where sp.session_id = session_id and sp.user_id = auth.uid()
    )
  );
create policy "Participants can upsert hole states" on public.hole_states
  for all using (
    exists (
      select 1 from public.session_players sp
      where sp.session_id = session_id and sp.user_id = auth.uid()
    )
  );

-- ─── Round History ────────────────────────────────────────────────────────────
-- Completed rounds stored per-player for stats
create table if not exists public.round_history (
  id          uuid default uuid_generate_v4() primary key,
  session_id  uuid references public.game_sessions(id),
  user_id     uuid references public.profiles(id) not null,
  course_name text,
  played_at   timestamptz default now(),
  total_score int,
  net_winnings numeric(10,2) default 0,
  game_modes  text[] default '{}',
  player_count int
);

alter table public.round_history enable row level security;
create policy "Users view own history" on public.round_history
  for select using (user_id = auth.uid());
create policy "System inserts history" on public.round_history
  for insert with check (user_id = auth.uid());

-- ─── Enable Realtime ─────────────────────────────────────────────────────────
-- Run these to enable realtime on the tables that need live sync
alter publication supabase_realtime add table public.scores;
alter publication supabase_realtime add table public.session_players;
alter publication supabase_realtime add table public.game_sessions;
alter publication supabase_realtime add table public.hole_states;

-- ─── Indexes ─────────────────────────────────────────────────────────────────
create index if not exists idx_session_players_session on public.session_players(session_id);
create index if not exists idx_scores_session on public.scores(session_id);
create index if not exists idx_hole_states_session on public.hole_states(session_id);
create index if not exists idx_round_history_user on public.round_history(user_id);
create index if not exists idx_game_sessions_join_code on public.game_sessions(join_code);

