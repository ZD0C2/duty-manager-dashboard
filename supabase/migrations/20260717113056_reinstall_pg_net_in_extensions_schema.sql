-- pg_net doesn't support ALTER EXTENSION ... SET SCHEMA (confirmed by a
-- failed attempt), so moving it out of public requires drop + recreate.
-- It holds no application data of its own (just an async HTTP client),
-- so this is safe; net.http_post is re-verified against the escalation
-- function immediately after.
drop extension pg_net;
create extension pg_net schema extensions;
