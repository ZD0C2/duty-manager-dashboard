-- SEC-1 fix: the invite-acceptance branch of this policy compared the
-- invitation row to itself (invitation.property_id = invitation.property_id,
-- invitation.role = invitation.role, invitation.department_id vs itself)
-- instead of to the row actually being inserted. That meant the policy
-- alone never verified the new membership's property/role/department
-- matched the invitation being redeemed -- only the accept_property_invitation
-- trigger did. This rewrites the EXISTS subquery to bind against
-- property_staff.property_id / .role / .department_id (the new row),
-- so the policy enforces the same enforcement as the trigger.

drop policy if exists "Owners managers and invitees can add memberships" on public.property_staff;

create policy "Owners managers and invitees can add memberships"
on public.property_staff
as permissive
for insert
to authenticated
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
      select 1
      from public.property_invitations invitation
      where invitation.id = property_staff.invite_id
        and invitation.property_id = property_staff.property_id
        and not (invitation.department_id is distinct from property_staff.department_id)
        and invitation.role = property_staff.role
        and invitation.active = true
        and invitation.accepted_at is null
        and invitation.expires_at > now()
        and lower(invitation.email) = lower(coalesce((select auth.jwt() ->> 'email'), ''))
    )
  )
);
