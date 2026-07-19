-- private.notification_deliveries has RLS enabled with no policies, which
-- is intentional (service-role only, never reachable via PostgREST for any
-- other role) but the security advisor flags it as an INFO-level lint
-- because "RLS enabled, no policy" is indistinguishable from an oversight.
-- Document the intent explicitly and add a permissive service_role policy
-- so the advisor can see this is a deliberate lockout, not a gap.
comment on table private.notification_deliveries is
  'Service-role-only idempotency ledger for guest-report notification delivery. Never exposed via PostgREST to any other role; RLS is enabled with a service_role-only policy as defense in depth, not because other roles are expected to reach this table.';

create policy "Service role only" on private.notification_deliveries
  for all
  to service_role
  using (true)
  with check (true);
