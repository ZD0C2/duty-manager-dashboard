create or replace function private.has_guest_portal_access(
  target_property_id uuid,
  target_location_id uuid default null
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.guest_portal_sessions portal_session
    join public.properties property
      on property.id = portal_session.property_id
     and property.public_id = portal_session.property_token
     and property.active = true
    join public.property_locations location
      on location.id = portal_session.location_id
     and location.property_id = portal_session.property_id
     and location.public_id = portal_session.location_token
     and location.active = true
    where portal_session.user_id = (select auth.uid())
      and portal_session.property_id = target_property_id
      and portal_session.expires_at > now()
      and (target_location_id is null or portal_session.location_id = target_location_id)
  );
$$;

revoke all on function private.has_guest_portal_access(uuid, uuid) from public, anon;
grant execute on function private.has_guest_portal_access(uuid, uuid) to authenticated;