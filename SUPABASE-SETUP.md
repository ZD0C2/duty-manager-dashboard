# InnRelay Multi-Hotel Supabase Setup

InnRelay now has two connected browser experiences:

- `innrelay-prototype.html` — authenticated owner and staff operations portal.
- `innrelay-guest.html` — no-install guest portal opened from a hotel/location QR code.

The guest portal never asks the guest to choose a hotel. A valid QR establishes one property boundary, and the guest may correct only the room or area inside that property.

## Live project

- Supabase project reference: `bkwzfoleuwhnuhqzxyqo`
- API URL: `https://bkwzfoleuwhnuhqzxyqo.supabase.co`
- Public staff page: `https://zd0c2.github.io/duty-manager-dashboard/innrelay-prototype.html`
- Public guest page: `https://zd0c2.github.io/duty-manager-dashboard/innrelay-guest.html`

`innrelay-supabase-config.js` contains only a publishable browser key. Never add a `service_role` key, database password, OAuth client secret, or JWT secret to the repository.

## Database foundation

The original two pilot migrations and the multi-hotel migration are applied to the live project:

1. `supabase/migrations/20260713181500_innrelay_guest_staff_pilot.sql`
2. `supabase/migrations/20260713181600_consolidate_insert_policies.sql`
3. `SUPABASE-MULTI-HOTEL-MIGRATION.sql`

The multi-hotel layer adds:

- self-service properties with separate public and internal identities;
- owner membership created atomically with a new property;
- property departments and category routing;
- rooms and public-area records with non-guessable QR capabilities;
- email-bound staff invitations;
- property-scoped staff assignment;
- guest portal capability sessions;
- automatic acknowledgement, escalation and retention deadlines;
- basic guest submission rate limiting;
- Row Level Security for property, staff, invitation, room and report isolation.

## Google sign-in configuration

In Google Cloud, use a **Web application** OAuth client.

Authorized JavaScript origins:

```text
https://zd0c2.github.io
http://localhost:8080
```

Authorized redirect URI — this must match character for character:

```text
https://bkwzfoleuwhnuhqzxyqo.supabase.co/auth/v1/callback
```

In Supabase **Authentication > URL Configuration** set the production Site URL and allowed redirect URL to:

```text
https://zd0c2.github.io/duty-manager-dashboard/innrelay-prototype.html
```

Keep `http://localhost:8080/innrelay-prototype.html` as an additional redirect only while developing locally. In Supabase **Authentication > Providers > Google**, enable Google and store the Google client ID and client secret there. The secret belongs in Supabase/Google Cloud only, never in the app files.

## Hotel directory menu

Google sign-in and Google hotel search use different credentials. The OAuth client above cannot power the hotel menu.

1. In the same Google Cloud project, enable **Places API (New)** and billing.
2. Create a separate browser API key.
3. Restrict the key to **Maps JavaScript API** and **Places API (New)**.
4. Restrict website access to:

```text
https://zd0c2.github.io/duty-manager-dashboard/*
http://localhost:8080/*
```

5. Put that restricted browser key in `innrelay-supabase-config.js` as `googlePlacesApiKey`.

Add the future `https://innrelay.com/*` referrer before moving to the custom domain. The key is deliberately blank in source until these restrictions exist. Owners can still use manual entry, but a directory selection stores Google's place ID and prevents the same hotel being registered twice.

## Owner onboarding

1. Open the public staff page.
2. Select **Continue with Google**.
3. If the account has no hotel, InnRelay opens **Register your first property**.
4. Choose the property from the hotel menu, or use manual entry for an unlisted property; then confirm the URL name, reception contact and colour.
5. InnRelay creates the owner membership, five default departments, sensible category routes, and common public areas.
6. Use **Property settings** to add numbered room ranges, change routing, invite staff and register another hotel.

Owners can switch between their authorised hotels from the property selector. Staff see only properties represented by an active membership.

## Staff invitations

The owner creates an invitation for the employee's exact email address. Send the generated link privately. The employee must open it and sign in with the same Google email. The invitation is single-use, expires after seven days and cannot grant access to another property.

## QR generation

Create rooms and areas first, then use **Guest Inbox > Guest-room QR code**. A staff member can type any single room number, or create a numbered range of up to 500 rooms in one action. InnRelay generates QR images locally in the browser and prints batch cards on A4 sheets, six cards per page. Existing room codes are kept rather than duplicated.

The GitHub Pages pilot URL contains secure query capabilities plus a readable route hint, for example:

```text
https://zd0c2.github.io/duty-manager-dashboard/innrelay-guest.html?pid=PROPERTY_ID&lid=LOCATION_ID&p=PROPERTY_TOKEN&l=LOCATION_TOKEN#/g/exhibition-court/r/208
```

Do not hand-edit or reuse the IDs/tokens between hotels. On a production host that supports rewrites, expose the cleaner public route:

```text
https://innrelay.com/g/exhibition-court/r/208
```

The server or edge layer should resolve that route to the same non-guessable property/location capabilities. Verify the exact public guest page on a phone before printing any QR cards.

## End-to-end release test

1. Register a second test hotel with the owner account.
2. Add two rooms and one public area.
3. Invite a separate staff email and accept the link with that exact account.
4. Confirm that account cannot see the first hotel.
5. Generate and scan one room QR in a private browser.
6. Confirm the guest may choose another location only inside the scanned hotel.
7. Submit a request and confirm its department and deadlines are assigned automatically.
8. Assign it to a property team member, acknowledge it, start work and resolve it with a note.
9. Confirm the guest sees the staff update.
10. Run Supabase Security and Performance Advisors after every migration.

## Controls before selling the service

- Enable CAPTCHA/bot protection for anonymous sign-in and review Auth rate limits.
- Enable leaked-password protection for password fallback, or remove password fallback if Google-only access is chosen.
- Add background push/email delivery; the current build has opt-in alerts while the staff portal is open.
- Add private Supabase Storage policies before enabling photos or attachments.
- Automate retention deletion and owner-requested property deletion.
- Add privacy terms, processor agreements, audit logging and a support process.
- Use HTTPS on a production host and configure the final custom domain before printing commercial QR stock.
- Do not accept payment-card numbers, passport scans or sensitive medical documents in request notes.
- Keep fire, violence, serious illness and immediate danger outside the queue: guests must call reception and emergency services first.

## Deliberately deferred

Do not build a native guest app or PMS integration yet. The initial product is a no-install guest web portal plus an optional installable staff PWA. Background push/email delivery, attachments, subscription billing and automated GDPR deletion are the next production phases on top of this property-safe foundation.
