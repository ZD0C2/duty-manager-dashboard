-- SEC-3: anonymous (guest) JWTs could previously insert into public.properties,
-- since the policy only checked created_by = auth.uid() -- true for anonymous
-- users too. This adds an explicit is_anonymous check so only a permanent
-- (Google or email/password) account can register a hotel.

drop policy if exists "Signed-in users can create properties" on public.properties;

create policy "Signed-in users can create properties"
on public.properties
as permissive
for insert
to authenticated
with check (
  created_by = (select auth.uid())
  and (select (auth.jwt() ->> 'is_anonymous')) is distinct from 'true'
);
