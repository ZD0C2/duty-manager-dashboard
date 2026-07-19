create index if not exists department_routes_department_fkey_idx
  on public.department_routes (property_id, department_id);
create index if not exists guest_reports_location_fkey_idx
  on public.guest_reports (property_id, location_id);
create index if not exists properties_created_by_idx
  on public.properties (created_by) where created_by is not null;
create index if not exists property_invitations_accepted_by_idx
  on public.property_invitations (accepted_by) where accepted_by is not null;
create index if not exists property_invitations_department_fkey_idx
  on public.property_invitations (property_id, department_id) where department_id is not null;
create index if not exists property_invitations_invited_by_idx
  on public.property_invitations (invited_by);
create index if not exists property_locations_department_fkey_idx
  on public.property_locations (property_id, department_id) where department_id is not null;
create index if not exists property_staff_department_fkey_idx
  on public.property_staff (property_id, department_id) where department_id is not null;

drop policy if exists "Owners managers and invitees can add memberships" on public.property_staff;
create policy "Owners managers and invitees can add memberships"
on public.property_staff for insert to authenticated
with check (
  (
    private.is_property_manager(property_id)
    and (role <> 'owner' or private.is_property_owner(property_id))
  )
  or (
    user_id = (select auth.uid())
    and role = 'owner'
    and invite_id is null
    and private.can_bootstrap_property_owner(property_id)
  )
  or (
    user_id = (select auth.uid())
    and invite_id is not null
    and exists (
      select 1 from public.property_invitations invitation
      where invitation.id = invite_id
        and invitation.property_id = property_id
        and invitation.department_id is not distinct from department_id
        and invitation.role = role
        and invitation.active = true
        and invitation.accepted_at is null
        and invitation.expires_at > now()
        and lower(invitation.email) = lower(coalesce((select auth.jwt()) ->> 'email', ''))
    )
  )
);

drop policy if exists "Managers and recipients can view invitations" on public.property_invitations;
create policy "Managers and recipients can view invitations"
on public.property_invitations for select to authenticated
using (
  private.is_property_manager(property_id)
  or lower(email) = lower(coalesce((select auth.jwt()) ->> 'email', ''))
);