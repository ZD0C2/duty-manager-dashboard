with route_map(category_key, department_code) as (
  values
  ('housekeeping-cleanliness','housekeeping'),
  ('linen-towels-toiletries','housekeeping'),
  ('laundry-dry-cleaning','housekeeping'),
  ('pest-hygiene-environment','housekeeping'),
  ('bathroom-plumbing','maintenance'),
  ('heating-cooling-air','maintenance'),
  ('electrical-lighting','maintenance'),
  ('room-furniture-fixtures','maintenance'),
  ('wifi-tv-phone-technology','maintenance'),
  ('public-areas-lifts','maintenance'),
  ('accessibility-mobility','maintenance'),
  ('spa-gym-pool-leisure','maintenance'),
  ('outdoor-grounds-smoking','maintenance'),
  ('sustainability-waste','maintenance'),
  ('building-maintenance','maintenance'),
  ('hotel-systems-it','maintenance'),
  ('breakfast','food-beverage'),
  ('restaurant-room-service','food-beverage'),
  ('bar-beverages','food-beverage'),
  ('food-allergy-dietary-safety','food-beverage'),
  ('minibar-vending-retail','food-beverage'),
  ('kitchen-food-operations','food-beverage'),
  ('stock-supplies','food-beverage'),
  ('medical-safety-emergency','duty-management'),
  ('fire-life-safety-compliance','duty-management'),
  ('security-incident','duty-management'),
  ('staffing-operations','duty-management'),
  ('cash-pos-financial','duty-management'),
  ('doors-keys-security','reception'),
  ('noise-disturbance','reception'),
  ('reception-reservations-checkin','reception'),
  ('billing-payments-refunds','reception'),
  ('guest-service-requests','reception'),
  ('parking-arrival-transport','reception'),
  ('family-children','reception'),
  ('pets-assistance-animals','reception'),
  ('lost-property-deliveries','reception'),
  ('meetings-events-business','reception'),
  ('staff-service-recovery','reception')
)
insert into public.department_routes (property_id, category_key, department_id)
select property.id, route_map.category_key, department.id
from public.properties property
join route_map on true
join public.property_departments department
  on department.property_id = property.id
 and department.code = route_map.department_code
where property.active = true
on conflict (property_id, category_key)
do update set department_id = excluded.department_id;