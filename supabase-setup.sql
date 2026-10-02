-- Run this in your Supabase project's SQL Editor.
-- Accounts are managed by Supabase Auth; this file creates the app's shared data tables.

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null unique check (char_length(username) between 4 and 10),
  profile_html text not null default '',
  profile_css text not null default '',
  created_at timestamptz not null default now()
);

-- Create each public profile automatically, including when email confirmation is enabled.
create or replace function public.create_profile_for_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, username)
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'username'), ''),
      'u' || left(replace(new.id::text, '-', ''), 9)
    )
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile
  after insert on auth.users
  for each row execute function public.create_profile_for_new_user();

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  content text not null,
  feeling text not null default '',
  image_url text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts (id) on delete cascade,
  author_id uuid not null references auth.users (id) on delete cascade,
  content text not null check (char_length(content) between 1 and 1000),
  created_at timestamptz not null default now()
);

create table if not exists public.post_reactions (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('vote', 'emoji')),
  value text not null,
  created_at timestamptz not null default now(),
  check (
    (kind = 'vote' and value in ('like', 'dislike')) or
    (kind = 'emoji' and value in ('❤️', '😂', '😮', '😢'))
  )
);
create unique index if not exists one_vote_per_user_per_post
  on public.post_reactions (post_id, user_id) where kind = 'vote';
create unique index if not exists one_emoji_reaction_per_user_per_post
  on public.post_reactions (post_id, user_id, value) where kind = 'emoji';

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  description text not null default '',
  location text not null default '',
  event_date timestamptz not null,
  created_at timestamptz not null default now()
);

create table if not exists public.event_responses (
  event_id uuid not null references public.events (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  response text not null check (response in ('yes', 'no', 'maybe')),
  created_at timestamptz not null default now(),
  primary key (event_id, user_id)
);

create table if not exists public.event_messages (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events (id) on delete cascade,
  author_id uuid not null references auth.users (id) on delete cascade,
  content text not null check (char_length(content) between 1 and 1000),
  created_at timestamptz not null default now()
);

create table if not exists public.quotes (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references auth.users (id) on delete cascade,
  content text not null check (char_length(content) between 1 and 1000),
  quoted_at timestamptz not null,
  created_at timestamptz not null default now()
);

-- A friendship is stored once, by the user who added the friend.
create table if not exists public.friendships (
  user_id uuid not null references auth.users (id) on delete cascade,
  friend_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, friend_id),
  check (user_id <> friend_id)
);

create table if not exists public.direct_messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users (id) on delete cascade,
  recipient_id uuid not null references auth.users (id) on delete cascade,
  content text not null check (char_length(content) between 1 and 2000),
  created_at timestamptz not null default now(),
  check (sender_id <> recipient_id)
);

-- Enable RLS on every table exposed to the browser.
alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.comments enable row level security;
alter table public.post_reactions enable row level security;
alter table public.events enable row level security;
alter table public.event_responses enable row level security;
alter table public.event_messages enable row level security;
alter table public.quotes enable row level security;
alter table public.friendships enable row level security;
alter table public.direct_messages enable row level security;

-- Policies are dropped first so this setup can be safely re-applied.
drop policy if exists "Profiles are public" on public.profiles;
drop policy if exists "Users create their own profile" on public.profiles;
drop policy if exists "Users update their own profile" on public.profiles;
drop policy if exists "Posts are public" on public.posts;
drop policy if exists "Signed-in users create their own posts" on public.posts;
drop policy if exists "Authors update their own posts" on public.posts;
drop policy if exists "Authors delete their own posts" on public.posts;
drop policy if exists "Comments are public" on public.comments;
drop policy if exists "Signed-in users comment as themselves" on public.comments;
drop policy if exists "Authors delete their own comments" on public.comments;
drop policy if exists "Reactions are public" on public.post_reactions;
drop policy if exists "Users add their own reactions" on public.post_reactions;
drop policy if exists "Users update their own reactions" on public.post_reactions;
drop policy if exists "Users delete their own reactions" on public.post_reactions;
drop policy if exists "Events are public" on public.events;
drop policy if exists "Signed-in users create their own events" on public.events;
drop policy if exists "Hosts update their own events" on public.events;
drop policy if exists "Hosts delete their own events" on public.events;
drop policy if exists "Event responses are public" on public.event_responses;
drop policy if exists "Users add their own event responses" on public.event_responses;
drop policy if exists "Users update their own event responses" on public.event_responses;
drop policy if exists "Users remove their own event responses" on public.event_responses;
drop policy if exists "Event messages are public" on public.event_messages;
drop policy if exists "Signed-in users send event messages as themselves" on public.event_messages;
drop policy if exists "Quotes are public" on public.quotes;
drop policy if exists "Signed-in users add quotes as themselves" on public.quotes;
drop policy if exists "Authors delete their own quotes" on public.quotes;
drop policy if exists "Users view their friendships" on public.friendships;
drop policy if exists "Users add friends for themselves" on public.friendships;
drop policy if exists "Either user removes a friendship" on public.friendships;
drop policy if exists "Conversation participants read messages" on public.direct_messages;
drop policy if exists "Users send messages as themselves to friends" on public.direct_messages;

create policy "Profiles are public" on public.profiles for select using (true);
create policy "Users create their own profile" on public.profiles for insert with check (auth.uid() = id);
create policy "Users update their own profile" on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);

create policy "Posts are public" on public.posts for select using (true);
create policy "Signed-in users create their own posts" on public.posts for insert with check (auth.uid() = author_id);
create policy "Authors update their own posts" on public.posts for update using (auth.uid() = author_id) with check (auth.uid() = author_id);
create policy "Authors delete their own posts" on public.posts for delete using (auth.uid() = author_id);

create policy "Comments are public" on public.comments for select using (true);
create policy "Signed-in users comment as themselves" on public.comments for insert with check (auth.uid() = author_id);
create policy "Authors delete their own comments" on public.comments for delete using (auth.uid() = author_id);

create policy "Reactions are public" on public.post_reactions for select using (true);
create policy "Users add their own reactions" on public.post_reactions for insert with check (auth.uid() = user_id);
create policy "Users update their own reactions" on public.post_reactions for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Users delete their own reactions" on public.post_reactions for delete using (auth.uid() = user_id);

create policy "Events are public" on public.events for select using (true);
create policy "Signed-in users create their own events" on public.events for insert with check (auth.uid() = host_id);
create policy "Hosts update their own events" on public.events for update using (auth.uid() = host_id) with check (auth.uid() = host_id);
create policy "Hosts delete their own events" on public.events for delete using (auth.uid() = host_id);

create policy "Event responses are public" on public.event_responses for select using (true);
create policy "Users add their own event responses" on public.event_responses for insert with check (auth.uid() = user_id);
create policy "Users update their own event responses" on public.event_responses for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Users remove their own event responses" on public.event_responses for delete using (auth.uid() = user_id);

create policy "Event messages are public" on public.event_messages for select using (true);
create policy "Signed-in users send event messages as themselves" on public.event_messages for insert with check (auth.uid() = author_id);

create policy "Quotes are public" on public.quotes for select using (true);
create policy "Signed-in users add quotes as themselves" on public.quotes for insert with check (auth.uid() = author_id);
create policy "Authors delete their own quotes" on public.quotes for delete using (auth.uid() = author_id);

create policy "Users view their friendships" on public.friendships for select using (auth.uid() = user_id or auth.uid() = friend_id);
create policy "Users add friends for themselves" on public.friendships for insert with check (auth.uid() = user_id);
create policy "Either user removes a friendship" on public.friendships for delete using (auth.uid() = user_id or auth.uid() = friend_id);

create policy "Conversation participants read messages" on public.direct_messages
  for select using (auth.uid() = sender_id or auth.uid() = recipient_id);
create policy "Users send messages as themselves to friends" on public.direct_messages
  for insert with check (
    auth.uid() = sender_id and exists (
      select 1 from public.friendships f
      where (f.user_id = sender_id and f.friend_id = recipient_id)
         or (f.user_id = recipient_id and f.friend_id = sender_id)
    )
  );

-- These indexes help the app load posts, comments, and chronological chats efficiently.
create index if not exists posts_created_at_idx on public.posts (created_at desc);
create index if not exists comments_post_created_at_idx on public.comments (post_id, created_at);
create index if not exists event_messages_event_created_at_idx on public.event_messages (event_id, created_at);
create index if not exists direct_messages_conversation_idx on public.direct_messages (sender_id, recipient_id, created_at);
