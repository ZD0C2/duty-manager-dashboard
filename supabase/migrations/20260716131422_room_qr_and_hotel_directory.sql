-- InnRelay room QR creation and verified hotel directory identities.
-- Staff may add room records only inside a property where they are active.
-- Managers retain the existing policy for all location types.

begin;

alter table public.properties
  add column if not exists external_place_provider text,
  add column if not exists external_place_id text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'properties_external_place_pair_check'
      and conrelid = 'public.properties'::regclass
  ) then
    alter table public.properties
      add constraint properties_external_place_pair_check
      check (
        (external_place_provider is null and external_place_id is null)
        or (
          external_place_provider = 'google_places'
          and char_length(external_place_id) between 3 and 255
        )
      );
  end if;
end $$;

create unique index if not exists properties_external_place_identity_key
  on public.properties (external_place_provider, external_place_id)
  where external_place_provider is not null and external_place_id is not null;

drop policy if exists "Staff can add rooms to their property" on public.property_locations;
create policy "Staff can add rooms to their property"
on public.property_locations
for insert
to authenticated
with check (
  location_type = 'room'
  and private.is_property_staff(property_id)
);

commit;
