-- Syanah · 0012 · Notifications (in-app feed) + per-channel delivery log + preferences.

begin;

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  title_key text not null,                               -- key into translations table
  body_key text,
  params jsonb,                                          -- substitutions for {var}
  resource_type text,                                    -- 'order' | 'message' | 'dispute' | ...
  resource_id uuid,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists notifications_user_unread_idx
  on public.notifications (user_id, read_at, created_at desc);

create table if not exists public.notification_deliveries (
  id bigserial primary key,
  notification_id uuid not null references public.notifications(id) on delete cascade,
  channel text not null check (channel in ('push','sms','email','in_app')),
  status text not null default 'pending' check (status in ('pending','sent','failed','suppressed')),
  provider_message_id text,
  attempted_at timestamptz not null default now(),
  error text
);

create index if not exists notification_deliveries_notification_idx
  on public.notification_deliveries (notification_id);

create table if not exists public.notification_preferences (
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  category text not null,                                -- 'order_status', 'chat', 'marketing', ...
  push_enabled boolean not null default true,
  sms_enabled boolean not null default false,
  email_enabled boolean not null default true,
  primary key (user_id, category)
);

alter table public.notifications enable row level security;
alter table public.notification_deliveries enable row level security;
alter table public.notification_preferences enable row level security;

drop policy if exists notifications_select_self on public.notifications;
create policy notifications_select_self
  on public.notifications for select
  to authenticated
  using (user_id = auth.uid() or public.user_is_admin(auth.uid()));

drop policy if exists notifications_update_self on public.notifications;
create policy notifications_update_self
  on public.notifications for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- inserts only via service_role (Edge Functions); no public insert policy.

drop policy if exists notification_deliveries_select_self on public.notification_deliveries;
create policy notification_deliveries_select_self
  on public.notification_deliveries for select
  to authenticated
  using (
    exists (
      select 1 from public.notifications n
      where n.id = notification_deliveries.notification_id
        and (n.user_id = auth.uid() or public.user_is_admin(auth.uid()))
    )
  );

drop policy if exists notification_preferences_rw_self on public.notification_preferences;
create policy notification_preferences_rw_self
  on public.notification_preferences for all
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- helper: emit a notification on order status change
create or replace function public.notify_on_order_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_recipients uuid[];
  v_title_key text;
begin
  v_title_key := case new.status
    when 'accepted'    then 'notifications.order_accepted'
    when 'en_route'    then 'notifications.order_en_route'
    when 'in_progress' then 'notifications.order_in_progress'
    when 'completed'   then 'notifications.order_completed'
    when 'cancelled'   then 'notifications.order_cancelled'
    when 'disputed'    then 'notifications.order_disputed'
    else null
  end;

  if v_title_key is null then return new; end if;

  v_recipients := array_remove(array[new.requester_id, new.provider_id], null);

  insert into public.notifications (user_id, title_key, params, resource_type, resource_id)
  select uid, v_title_key, jsonb_build_object('code', new.code), 'order', new.id
  from unnest(v_recipients) as uid;

  return new;
end;
$$;

drop trigger if exists orders_after_status_notify on public.orders;
create trigger orders_after_status_notify
  after update of status on public.orders
  for each row execute function public.notify_on_order_status_change();

commit;
