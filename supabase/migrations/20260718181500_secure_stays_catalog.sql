-- The Stays catalogue is non-sensitive reference data, but it still follows
-- Supabase's RLS-by-default rule. Callers can read active rows only; all writes
-- remain reserved for migrations/database owners.

alter table private.stays_issue_categories enable row level security;

drop policy if exists "Authenticated sessions can read active Stays categories"
  on private.stays_issue_categories;

create policy "Authenticated sessions can read active Stays categories"
on private.stays_issue_categories
for select
to authenticated
using (active = true);

revoke all on table private.stays_issue_categories from public, anon, authenticated;
grant select on table private.stays_issue_categories to authenticated;

