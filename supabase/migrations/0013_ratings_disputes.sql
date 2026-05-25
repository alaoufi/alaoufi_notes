-- Syanah · 0013 · Ratings, reviews, disputes, and dispute evidence.

begin;

do $$ begin
  if not exists (select 1 from pg_type where typname = 'dispute_status') then
    create type dispute_status as enum ('open','under_review','resolved_requester','resolved_provider','dismissed');
  end if;
end $$;

-- ratings (bi-directional: requester ↔ provider). One per (order, rater).

create table if not exists public.ratings (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  rater_id uuid not null references public.profiles(user_id) on delete restrict,
  ratee_id uuid not null references public.profiles(user_id) on delete restrict,
  score int not null check (score between 1 and 5),
  comment text check (length(comment) <= 2000),
  is_visible boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (order_id, rater_id)
);

drop trigger if exists ratings_set_updated_at on public.ratings;
create trigger ratings_set_updated_at
  before update on public.ratings
  for each row execute function public.set_updated_at();

create index if not exists ratings_ratee_idx on public.ratings (ratee_id, is_visible, score);

-- disputes (one per order)

create table if not exists public.disputes (
  id uuid primary key default gen_random_uuid(),
  order_id uuid unique not null references public.orders(id) on delete cascade,
  opened_by uuid not null references public.profiles(user_id) on delete restrict,
  reason text not null check (length(reason) between 3 and 200),
  description text check (length(description) <= 5000),
  status dispute_status not null default 'open',
  assigned_admin_id uuid references public.profiles(user_id),
  resolved_at timestamptz,
  resolution_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists disputes_set_updated_at on public.disputes;
create trigger disputes_set_updated_at
  before update on public.disputes
  for each row execute function public.set_updated_at();

create index if not exists disputes_status_idx on public.disputes (status, created_at desc);
create index if not exists disputes_admin_idx on public.disputes (assigned_admin_id);

create table if not exists public.dispute_evidence (
  id uuid primary key default gen_random_uuid(),
  dispute_id uuid not null references public.disputes(id) on delete cascade,
  artifact_type text not null check (artifact_type in ('chat_export','message','photo','audio','other')),
  path text,
  message_id uuid references public.messages(id),
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists dispute_evidence_dispute_idx on public.dispute_evidence (dispute_id);

create table if not exists public.dispute_actions (
  id bigserial primary key,
  dispute_id uuid not null references public.disputes(id) on delete cascade,
  actor_id uuid not null references public.profiles(user_id),
  action text not null,
  payload jsonb,
  created_at timestamptz not null default now()
);

-- Hide ratings of an order when a dispute is opened; restore on dismiss/resolution.
create or replace function public.toggle_ratings_visibility_on_dispute()
returns trigger language plpgsql as $$
begin
  if (tg_op = 'INSERT') then
    update public.ratings set is_visible = false where order_id = new.order_id;
  elsif (tg_op = 'UPDATE') then
    if new.status in ('resolved_requester','resolved_provider','dismissed')
       and old.status not in ('resolved_requester','resolved_provider','dismissed') then
      update public.ratings set is_visible = true where order_id = new.order_id;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists disputes_toggle_ratings on public.disputes;
create trigger disputes_toggle_ratings
  after insert or update of status on public.disputes
  for each row execute function public.toggle_ratings_visibility_on_dispute();

-- Move order status to 'disputed' when a dispute is opened.
create or replace function public.mark_order_disputed()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update public.orders set status = 'disputed' where id = new.order_id and status in ('in_progress','completed');
  return new;
end;
$$;

drop trigger if exists disputes_after_insert_mark_order on public.disputes;
create trigger disputes_after_insert_mark_order
  after insert on public.disputes
  for each row execute function public.mark_order_disputed();

-- RLS

alter table public.ratings enable row level security;
alter table public.disputes enable row level security;
alter table public.dispute_evidence enable row level security;
alter table public.dispute_actions enable row level security;

-- ratings: visible (is_visible) ratings readable to anyone; rater + ratee + admin always.
drop policy if exists ratings_select_visible on public.ratings;
create policy ratings_select_visible
  on public.ratings for select
  to anon, authenticated
  using (
    is_visible
    or rater_id = auth.uid()
    or ratee_id = auth.uid()
    or public.user_is_admin(auth.uid())
  );

drop policy if exists ratings_insert_participant on public.ratings;
create policy ratings_insert_participant
  on public.ratings for insert
  to authenticated
  with check (
    rater_id = auth.uid()
    and exists (
      select 1 from public.orders o
      where o.id = order_id
        and o.status = 'completed'
        and (o.requester_id = auth.uid() or o.provider_id = auth.uid())
        and not exists (select 1 from public.disputes d where d.order_id = o.id and d.status = 'open')
    )
  );

drop policy if exists ratings_update_self on public.ratings;
create policy ratings_update_self
  on public.ratings for update
  to authenticated
  using (rater_id = auth.uid())
  with check (rater_id = auth.uid());

-- disputes: participants + assigned admin can read; only participants can open
drop policy if exists disputes_select_participants on public.disputes;
create policy disputes_select_participants
  on public.disputes for select
  to authenticated
  using (
    public.user_is_admin(auth.uid())
    or exists (
      select 1 from public.orders o
      where o.id = disputes.order_id
        and (o.requester_id = auth.uid() or o.provider_id = auth.uid())
    )
  );

drop policy if exists disputes_insert_participant on public.disputes;
create policy disputes_insert_participant
  on public.disputes for insert
  to authenticated
  with check (
    opened_by = auth.uid()
    and exists (
      select 1 from public.orders o
      where o.id = order_id
        and (o.requester_id = auth.uid() or o.provider_id = auth.uid())
    )
  );

drop policy if exists disputes_update_admin on public.disputes;
create policy disputes_update_admin
  on public.disputes for update
  to authenticated
  using (public.user_is_admin(auth.uid()))
  with check (public.user_is_admin(auth.uid()));

-- dispute_evidence
drop policy if exists dispute_evidence_read_participants on public.dispute_evidence;
create policy dispute_evidence_read_participants
  on public.dispute_evidence for select
  to authenticated
  using (
    public.user_is_admin(auth.uid())
    or exists (
      select 1 from public.disputes d
      join public.orders o on o.id = d.order_id
      where d.id = dispute_evidence.dispute_id
        and (o.requester_id = auth.uid() or o.provider_id = auth.uid())
    )
  );

drop policy if exists dispute_evidence_insert_participant on public.dispute_evidence;
create policy dispute_evidence_insert_participant
  on public.dispute_evidence for insert
  to authenticated
  with check (
    public.user_is_admin(auth.uid())
    or exists (
      select 1 from public.disputes d
      join public.orders o on o.id = d.order_id
      where d.id = dispute_id
        and (o.requester_id = auth.uid() or o.provider_id = auth.uid())
    )
  );

-- dispute_actions: admin write only; visible to participants
drop policy if exists dispute_actions_read on public.dispute_actions;
create policy dispute_actions_read
  on public.dispute_actions for select
  to authenticated
  using (
    public.user_is_admin(auth.uid())
    or exists (
      select 1 from public.disputes d
      join public.orders o on o.id = d.order_id
      where d.id = dispute_actions.dispute_id
        and (o.requester_id = auth.uid() or o.provider_id = auth.uid())
    )
  );

drop policy if exists dispute_actions_insert_admin on public.dispute_actions;
create policy dispute_actions_insert_admin
  on public.dispute_actions for insert
  to authenticated
  with check (public.user_is_admin(auth.uid()));

-- Provider stats materialized view (refreshed periodically by cron)
drop materialized view if exists public.provider_stats;
create materialized view public.provider_stats as
select
  p.user_id as provider_id,
  coalesce(avg(r.score) filter (where r.is_visible), 0)::numeric(3,2) as avg_rating,
  count(r.id) filter (where r.is_visible) as ratings_count,
  count(distinct o.id) filter (where o.status = 'completed') as completed_orders,
  count(distinct o.id) filter (where o.status = 'cancelled' and o.cancelled_by = p.user_id) as provider_cancellations
from public.providers p
left join public.orders o on o.provider_id = p.user_id
left join public.ratings r on r.ratee_id = p.user_id
group by p.user_id;

create unique index if not exists provider_stats_provider_id_idx on public.provider_stats(provider_id);

commit;
