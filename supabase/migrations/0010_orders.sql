-- Syanah · 0010 · Orders, status history, attachments + state machine trigger + notifications.

begin;

do $$ begin
  if not exists (select 1 from pg_type where typname = 'order_status') then
    create type order_status as enum (
      'draft','pending','accepted','rejected','en_route','in_progress',
      'completed','cancelled','disputed'
    );
  end if;
end $$;

-- orders

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  code text unique not null default ('SY-' || to_char(now(), 'YYYY') || '-' || lpad((floor(random()*999999))::text, 6, '0')),
  requester_id uuid not null references public.profiles(user_id) on delete restrict,
  provider_id uuid references public.profiles(user_id) on delete restrict,
  category_id uuid not null references public.categories(id),
  subcategory_id uuid references public.subcategories(id),
  service_id uuid references public.services(id),
  status order_status not null default 'pending',
  scheduled_at timestamptz,
  address_label text not null,
  address_details text,
  location geography(Point, 4326) not null,
  city_id uuid references public.cities(id),
  district_id uuid references public.districts(id),
  notes text,
  estimated_total numeric(12,2),
  final_total numeric(12,2),
  currency text not null default 'SAR',
  cancellation_reason text,
  cancelled_by uuid references public.profiles(user_id),
  accepted_at timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists orders_set_updated_at on public.orders;
create trigger orders_set_updated_at
  before update on public.orders
  for each row execute function public.set_updated_at();

create index if not exists orders_requester_status_idx on public.orders (requester_id, status, created_at desc);
create index if not exists orders_provider_status_idx  on public.orders (provider_id, status, created_at desc);
create index if not exists orders_location_gix         on public.orders using gist (location);
create index if not exists orders_active_idx
  on public.orders (status, created_at desc)
  where status in ('pending','accepted','en_route','in_progress');

-- order_status_history

create table if not exists public.order_status_history (
  id bigserial primary key,
  order_id uuid not null references public.orders(id) on delete cascade,
  from_status order_status,
  to_status order_status not null,
  changed_by uuid references public.profiles(user_id),
  reason text,
  created_at timestamptz not null default now()
);

create index if not exists order_history_order_idx on public.order_status_history (order_id, created_at desc);

-- state machine validation trigger

create or replace function public.validate_order_status_transition()
returns trigger
language plpgsql
as $$
declare
  v_valid boolean;
begin
  if new.status = old.status then
    return new;
  end if;

  v_valid := case
    when old.status = 'pending'      and new.status in ('accepted','rejected','cancelled')         then true
    when old.status = 'accepted'     and new.status in ('en_route','cancelled')                    then true
    when old.status = 'en_route'     and new.status in ('in_progress','cancelled')                 then true
    when old.status = 'in_progress'  and new.status in ('completed','disputed')                    then true
    when old.status = 'completed'    and new.status in ('disputed')                                then true
    when old.status = 'disputed'     and new.status in ('completed','cancelled')                   then true
    else false
  end;

  if not v_valid then
    raise exception 'ORDER_INVALID_TRANSITION from % to %', old.status, new.status using errcode = 'P0001';
  end if;

  -- timestamp side-effects
  if new.status = 'accepted' and old.status <> 'accepted' then new.accepted_at := now(); end if;
  if new.status = 'in_progress' and old.status <> 'in_progress' then new.started_at := now(); end if;
  if new.status = 'completed' and old.status <> 'completed' then new.completed_at := now(); end if;
  if new.status = 'cancelled' and old.status <> 'cancelled' then new.cancelled_at := now(); end if;

  insert into public.order_status_history (order_id, from_status, to_status, changed_by)
  values (new.id, old.status, new.status, auth.uid());

  return new;
end;
$$;

drop trigger if exists orders_validate_status on public.orders;
create trigger orders_validate_status
  before update of status on public.orders
  for each row execute function public.validate_order_status_transition();

-- order_attachments (photos uploaded by requester at creation)

create table if not exists public.order_attachments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  uploaded_by uuid not null references public.profiles(user_id) on delete restrict,
  path text not null,
  mime text,
  size_bytes int,
  created_at timestamptz not null default now()
);

create index if not exists order_attachments_order_idx on public.order_attachments (order_id);

-- RLS

alter table public.orders enable row level security;
alter table public.order_status_history enable row level security;
alter table public.order_attachments enable row level security;

-- orders policies

drop policy if exists orders_select_participants on public.orders;
create policy orders_select_participants
  on public.orders for select
  to authenticated
  using (
    requester_id = auth.uid()
    or provider_id = auth.uid()
    or public.user_is_admin(auth.uid())
  );

drop policy if exists orders_insert_requester on public.orders;
create policy orders_insert_requester
  on public.orders for insert
  to authenticated
  with check (
    requester_id = auth.uid()
    and public.user_has_role(auth.uid(), 'requester')
  );

-- update split: provider can only accept/reject and progress; requester can only cancel pending.
drop policy if exists orders_update_provider on public.orders;
create policy orders_update_provider
  on public.orders for update
  to authenticated
  using (provider_id = auth.uid())
  with check (provider_id = auth.uid());

drop policy if exists orders_update_requester_cancel on public.orders;
create policy orders_update_requester_cancel
  on public.orders for update
  to authenticated
  using (requester_id = auth.uid())
  with check (requester_id = auth.uid());

drop policy if exists orders_update_admin on public.orders;
create policy orders_update_admin
  on public.orders for update
  to authenticated
  using (public.user_is_admin(auth.uid()))
  with check (public.user_is_admin(auth.uid()));

-- status history readable by order participants
drop policy if exists order_history_select_participants on public.order_status_history;
create policy order_history_select_participants
  on public.order_status_history for select
  to authenticated
  using (
    exists (
      select 1 from public.orders o
      where o.id = order_status_history.order_id
        and (o.requester_id = auth.uid() or o.provider_id = auth.uid()
             or public.user_is_admin(auth.uid()))
    )
  );

-- attachments
drop policy if exists order_attachments_rw on public.order_attachments;
create policy order_attachments_rw
  on public.order_attachments for all
  to authenticated
  using (
    exists (
      select 1 from public.orders o
      where o.id = order_attachments.order_id
        and (o.requester_id = auth.uid() or o.provider_id = auth.uid()
             or public.user_is_admin(auth.uid()))
    )
  )
  with check (
    exists (
      select 1 from public.orders o
      where o.id = order_attachments.order_id
        and o.requester_id = auth.uid()
    )
  );

commit;
