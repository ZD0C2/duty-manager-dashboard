-- Enforce at the database level that a hotel property can never route to a
-- Stays-only category and vice versa. Previously only enforced by which
-- onboarding RPC populated the table (create_stays_workspace vs the hotel
-- onboarding path), not by a constraint. Stays categories are the sole
-- source of truth in private.stays_issue_categories and are all namespaced
-- with the "str-" prefix (confirmed zero str- categories exist in the
-- hotel-only client catalogue).
create or replace function private.guard_department_route_vertical()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare
  target_property_type text;
  is_stays_category boolean;
begin
  select property.property_type into target_property_type
  from public.properties property
  where property.id = new.property_id;

  is_stays_category := new.category_key like 'str-%';

  if target_property_type = 'short_term_rental' then
    if not exists (
      select 1 from private.stays_issue_categories category
      where category.category_key = new.category_key
    ) then
      raise exception 'This category is not part of the InnRelay Stays catalogue.';
    end if;
  elsif is_stays_category then
    raise exception 'This category belongs to InnRelay Stays and cannot be routed for a hotel property.';
  end if;

  return new;
end;
$function$;

drop trigger if exists guard_department_route_vertical on public.department_routes;
create trigger guard_department_route_vertical
  before insert or update on public.department_routes
  for each row execute function private.guard_department_route_vertical();
