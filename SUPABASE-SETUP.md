# InnRelay Guest + Staff Supabase Free Pilot

This build contains two connected browser experiences:

- `innrelay-guest.html` - the QR guest portal.
- `innrelay-prototype.html` - the staff dashboard, Guest Inbox, Live Board and Shift Run.

Both pages are connected to the dedicated InnRelay Supabase project. They retain a same-device demo fallback so the interface remains reviewable if the live service is unavailable.

## 1. InnRelay project and database (complete)

The dedicated **InnRelay** Free project is active in the London region (`eu-west-2`):

- Project reference: `bkwzfoleuwhnuhqzxyqo`
- API URL: `https://bkwzfoleuwhnuhqzxyqo.supabase.co`
- Seed property: `Exhibition Court Hotel` / `exhibition-court`

Clinic Companion was paused before this project was created, so the confirmed current project charge is **US$0 per month** on the organisation's Free plan. Supabase Free projects can be paused for inactivity or become chargeable if the organisation is upgraded; review the dashboard before changing plans or resuming other projects.

Apply:

`supabase/migrations/20260713181500_innrelay_guest_staff_pilot.sql`

Then apply:

`supabase/migrations/20260713181600_consolidate_insert_policies.sql`

The migration creates:

- `properties`
- `property_staff`
- `guest_reports`
- `guest_report_updates`
- indexes, timestamp triggers and Realtime publication entries
- explicit Data API grants
- Row Level Security on every exposed table

Both migrations are already applied to the live project. Supabase Security Advisor reported no findings after deployment. Performance Advisor reported only expected unused-index information because the new tables contain no guest reports yet.

## 2. Enable anonymous guest sessions (manual action required)

In Supabase Dashboard, open **Authentication > Providers > Anonymous Sign-Ins** and enable anonymous sign-ins.

Guests do not create passwords. Each browser receives a private Supabase user ID, and RLS permits it to read only reports created by that ID. Anonymous sessions use the `authenticated` database role; the policies differentiate ownership using `auth.uid()`.

Before sharing the portal publicly, enable Cloudflare Turnstile or another supported CAPTCHA in **Authentication > Bot and Abuse Protection**. Also review the Auth rate limits.

## 3. Create and link the first staff user

Create a permanent staff user under **Authentication > Users**. Then run this once in the SQL editor, replacing the example email and display name:

```sql
insert into public.property_staff (property_id, user_id, display_name, role)
select property.id, staff.id, 'Duty Manager', 'owner'
from public.properties property
join auth.users staff on lower(staff.email) = lower('manager@example.com')
where property.slug = 'exhibition-court'
on conflict (property_id, user_id) do update set
  display_name = excluded.display_name,
  role = excluded.role,
  active = true;
```

That user can sign in from **Guest Inbox** on the staff dashboard. Add more staff through the same table or a later manager screen.

## 4. Public browser configuration (complete)

`innrelay-supabase-config.js` now contains the live API URL and modern publishable key, with `demoMode: false`.

For a different deployment, enter only:

```js
supabaseUrl: "https://YOUR_PROJECT_REF.supabase.co",
supabasePublishableKey: "sb_publishable_YOUR_KEY",
demoMode: false
```

A Supabase publishable key is designed for public browser clients. Security comes from RLS. Never place a secret key, JWT secret or legacy `service_role` key in an HTML or JavaScript file.

## 5. Test the end-to-end flow

Serve the folder through HTTP rather than opening files directly:

```bash
python3 -m http.server 8080
```

Then:

1. Open `http://localhost:8080/innrelay-prototype.html` and sign in under Guest Inbox.
2. Open `http://localhost:8080/innrelay-guest.html?property=exhibition-court&room=208` in another browser or private profile.
3. Submit a guest request.
4. Confirm it appears in Guest Inbox and on the Live Board.
5. Acknowledge it, start work, add an update and resolve it.
6. Confirm the guest page receives each status change.

## 6. Create room QR codes

Each room QR uses the same guest page with a different room parameter:

```text
https://YOUR_DOMAIN/innrelay-guest.html?property=exhibition-court&room=208
```

The room parameter improves convenience; it is not proof of booking identity. Staff must still verify unusual, high-value or security-sensitive requests before acting.

## Required controls before a public launch

- Add CAPTCHA and rate limiting for anonymous sign-ins and submissions.
- Use HTTPS and move the commercial build away from GitHub Pages.
- Add a concise guest privacy notice, retention period and deletion process.
- Do not accept card numbers, passport scans or sensitive documents in notes.
- Keep medical, fire, violence and immediate-danger guidance outside the request queue: guests must call reception and emergency services first.
- Review Supabase Security Advisor after every schema or policy change.
- Test RLS with separate guest, staff and unrelated-user accounts.
- Decide how long anonymous users, reports and operational history are retained.

## Catalogue coverage

`innrelay-issue-catalog.js` is the shared staff and guest catalogue. It includes guest-room, housekeeping, plumbing, climate, electrical, technology, access, food and drink, reservations, billing, accessibility, leisure, events, safety, security, maintenance, kitchen, stock, cash, IT and staffing issues.

Every category includes **Other / something else**, and both apps accept a custom title and description. That is intentional: no fixed catalogue can predict every real hotel situation.
