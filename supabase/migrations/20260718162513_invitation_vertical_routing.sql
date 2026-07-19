-- Let an invited human determine which InnRelay vertical should accept their
-- token without exposing property data before membership exists.

create or replace function public.invitation_vertical(p_token uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select property.property_type
  from public.property_invitations invitation
  join public.properties property on property.id = invitation.property_id
  where invitation.token = p_token
    and invitation.active = true
    and invitation.accepted_at is null
    and invitation.expires_at > now()
    and lower(invitation.email) = lower(coalesce((select auth.jwt()->>'email'), ''))
    and (select auth.uid()) is not null
    and coalesce((select auth.jwt()->>'is_anonymous'), 'false') <> 'true'
  limit 1;
$$;

revoke all on function public.invitation_vertical(uuid) from public, anon;
grant execute on function public.invitation_vertical(uuid) to authenticated;
