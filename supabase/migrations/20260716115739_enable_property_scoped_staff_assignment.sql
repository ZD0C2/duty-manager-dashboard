drop policy if exists "Staff can view relevant memberships" on public.property_staff;
create policy "Property staff can view team memberships"
on public.property_staff for select to authenticated
using (private.is_property_staff(property_id));

create or replace function private.validate_guest_report_owner()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  assigned_display_name text;
begin
  if new.owner_user_id is null then
    new.owner_display := null;
    return new;
  end if;

  select membership.display_name
  into assigned_display_name
  from public.property_staff membership
  where membership.property_id = new.property_id
    and membership.user_id = new.owner_user_id
    and membership.active = true;

  if assigned_display_name is null then
    raise exception 'The selected assignee is not active staff for this property.';
  end if;

  new.owner_display := assigned_display_name;
  return new;
end;
$$;

drop trigger if exists validate_guest_report_owner on public.guest_reports;
create trigger validate_guest_report_owner
before insert or update of owner_user_id, property_id on public.guest_reports
for each row execute function private.validate_guest_report_owner();

revoke all on function private.validate_guest_report_owner() from public, anon, authenticated;