begin;

drop policy if exists "Managers can add locations" on public.property_locations;
drop policy if exists "Staff can add rooms to their property" on public.property_locations;
drop policy if exists "Property staff can add permitted locations" on public.property_locations;

create policy "Property staff can add permitted locations"
on public.property_locations
for insert
to authenticated
with check (
  private.is_property_manager(property_id)
  or (location_type = 'room' and private.is_property_staff(property_id))
);

commit;
