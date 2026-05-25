-- Syanah · 0009 · Chat tables: conversations, messages, message_reads, typing_indicators.

begin;

do $$ begin
  if not exists (select 1 from pg_type where typname = 'message_type') then
    create type message_type as enum ('text', 'image', 'file', 'voice', 'location', 'system');
  end if;
end $$;

-- conversations: 1:1 with orders (FK added once orders exist in migration 0010 stub).

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  order_id uuid unique not null,                          -- FK added in 0011 (orders dep)
  is_archived boolean not null default false,
  archived_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists conversations_order_idx on public.conversations (order_id);
create index if not exists conversations_archived_idx on public.conversations (is_archived);

-- messages

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(user_id) on delete restrict,
  type message_type not null,
  body text,
  media_path text,
  media_mime text,
  media_size_bytes int,
  media_duration_ms int,
  waveform jsonb,                                          -- precomputed peaks for voice
  latitude double precision,
  longitude double precision,
  reply_to_message_id uuid references public.messages(id),
  edited_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  constraint messages_body_or_media check (
    type = 'system' or
    (type = 'text' and body is not null and length(body) between 1 and 4000) or
    (type in ('image','file','voice') and media_path is not null) or
    (type = 'location' and latitude is not null and longitude is not null)
  )
);

create index if not exists messages_conversation_created_idx
  on public.messages (conversation_id, created_at desc);
create index if not exists messages_sender_idx
  on public.messages (sender_id, created_at desc);

-- message_reads (per user)

create table if not exists public.message_reads (
  message_id uuid not null references public.messages(id) on delete cascade,
  reader_id uuid not null references public.profiles(user_id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (message_id, reader_id)
);

create index if not exists message_reads_reader_idx
  on public.message_reads (reader_id, read_at desc);

-- RLS

alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.message_reads enable row level security;

-- conversations: visible to admins until orders FK exists; tightened in 0011.
drop policy if exists conversations_select_temp on public.conversations;
create policy conversations_select_temp
  on public.conversations for select
  to authenticated
  using (public.user_is_admin(auth.uid()));

drop policy if exists conversations_write_super on public.conversations;
create policy conversations_write_super
  on public.conversations for all
  to authenticated
  using (public.user_has_role(auth.uid(), 'super_admin'))
  with check (public.user_has_role(auth.uid(), 'super_admin'));

-- messages: sender can write; reads scoped to admins until 0011 connects orders.
drop policy if exists messages_insert_sender on public.messages;
create policy messages_insert_sender
  on public.messages for insert
  to authenticated
  with check (
    sender_id = auth.uid()
    and not exists (
      select 1 from public.conversations c
      where c.id = messages.conversation_id and c.is_archived = true
    )
  );

drop policy if exists messages_select_admin_for_now on public.messages;
create policy messages_select_admin_for_now
  on public.messages for select
  to authenticated
  using (sender_id = auth.uid() or public.user_is_admin(auth.uid()));

-- message_reads
drop policy if exists message_reads_self on public.message_reads;
create policy message_reads_self
  on public.message_reads for all
  to authenticated
  using (reader_id = auth.uid())
  with check (reader_id = auth.uid());

commit;
