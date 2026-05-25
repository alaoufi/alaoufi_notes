-- Syanah · 0011 · Link chat/location to orders, replace temp policies with strict ones.

begin;

-- add FK from conversations to orders now that orders exist
do $$ begin
  if not exists (
    select 1 from information_schema.table_constraints
    where table_schema='public' and table_name='conversations'
      and constraint_name='conversations_order_id_fkey'
  ) then
    alter table public.conversations
      add constraint conversations_order_id_fkey
      foreign key (order_id) references public.orders(id) on delete cascade;
  end if;
end $$;

do $$ begin
  if not exists (
    select 1 from information_schema.table_constraints
    where table_schema='public' and table_name='location_pings'
      and constraint_name='location_pings_order_id_fkey'
  ) then
    alter table public.location_pings
      add constraint location_pings_order_id_fkey
      foreign key (order_id) references public.orders(id) on delete cascade;
  end if;
end $$;

-- Auto-create conversation when order is inserted
create or replace function public.create_conversation_for_order()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into public.conversations (order_id) values (new.id)
  on conflict (order_id) do nothing;
  return new;
end;
$$;

drop trigger if exists orders_after_insert_create_conversation on public.orders;
create trigger orders_after_insert_create_conversation
  after insert on public.orders
  for each row execute function public.create_conversation_for_order();

-- Auto-archive conversation when order completes
create or replace function public.archive_conversation_on_order_completion()
returns trigger language plpgsql
as $$
begin
  if new.status in ('completed','cancelled') and old.status not in ('completed','cancelled') then
    update public.conversations
       set is_archived = true, archived_at = now()
     where order_id = new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists orders_after_update_archive_chat on public.orders;
create trigger orders_after_update_archive_chat
  after update of status on public.orders
  for each row execute function public.archive_conversation_on_order_completion();

-- ----- Tighten policies for conversations / messages / location_pings -----

drop policy if exists conversations_select_temp on public.conversations;

drop policy if exists conversations_select_participants on public.conversations;
create policy conversations_select_participants
  on public.conversations for select
  to authenticated
  using (
    exists (
      select 1 from public.orders o
      where o.id = conversations.order_id
        and (o.requester_id = auth.uid() or o.provider_id = auth.uid()
             or public.user_is_admin(auth.uid()))
    )
  );

drop policy if exists messages_select_admin_for_now on public.messages;

drop policy if exists messages_select_participants on public.messages;
create policy messages_select_participants
  on public.messages for select
  to authenticated
  using (
    exists (
      select 1
      from public.conversations c
      join public.orders o on o.id = c.order_id
      where c.id = messages.conversation_id
        and (o.requester_id = auth.uid() or o.provider_id = auth.uid()
             or public.user_is_admin(auth.uid()))
    )
  );

-- restrict inserts to actual participants + non-archived
drop policy if exists messages_insert_sender on public.messages;
create policy messages_insert_participants
  on public.messages for insert
  to authenticated
  with check (
    sender_id = auth.uid()
    and exists (
      select 1
      from public.conversations c
      join public.orders o on o.id = c.order_id
      where c.id = messages.conversation_id
        and (o.requester_id = auth.uid() or o.provider_id = auth.uid())
        and c.is_archived = false
    )
  );

-- requester can now read location_pings of their own active order
drop policy if exists location_pings_select_requester on public.location_pings;
create policy location_pings_select_requester
  on public.location_pings for select
  to authenticated
  using (
    exists (
      select 1 from public.orders o
      where o.id = location_pings.order_id
        and o.requester_id = auth.uid()
        and o.status in ('en_route','in_progress')
    )
  );

commit;
