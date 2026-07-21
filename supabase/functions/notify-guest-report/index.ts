import { createClient } from "jsr:@supabase/supabase-js@2";

const ALLOWED_ORIGINS = new Set([
  "https://innrelay.com",
  "https://www.innrelay.com",
  "https://zd0c2.github.io",
  "http://localhost:8080",
  "http://127.0.0.1:8080",
]);

function corsHeaders(request: Request): Record<string, string> {
  const origin = request.headers.get("Origin") || "";
  return {
    "Access-Control-Allow-Origin": ALLOWED_ORIGINS.has(origin) ? origin : "https://innrelay.com",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
}

function json(request: Request, body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(request), "Content-Type": "application/json; charset=utf-8" },
  });
}

function escapeHtml(value: unknown): string {
  return String(value ?? "").replace(/[&<>\"']/g, (character) => {
    const map: Record<string, string> = {
      "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#039;",
    };
    return map[character];
  });
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders(request) });
  if (request.method !== "POST") return json(request, { error: "POST required" }, 405);

  const requestOrigin = request.headers.get("Origin") || "";
  if (requestOrigin && !ALLOWED_ORIGINS.has(requestOrigin)) return json(request, { error: "Origin not allowed" }, 403);

  try {
    const body = await request.json().catch(() => ({}));
    const reportId = typeof body.report_id === "string" ? body.report_id : "";
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(reportId)) {
      return json(request, { error: "A valid report_id is required" }, 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") || "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
    const resendApiKey = Deno.env.get("RESEND_API_KEY");
    if (!supabaseUrl || !anonKey || !serviceRoleKey) return json(request, { error: "Notification service unavailable" }, 503);

    const admin = createClient(supabaseUrl, serviceRoleKey, { auth: { persistSession: false } });
    const { data: report, error: reportError } = await admin
      .from("guest_reports")
      .select("id,title,description,location,category_label,urgency,guest_impact,status,property_id,department_id,guest_user_id,escalated_at,created_at,properties(name)")
      .eq("id", reportId)
      .single();
    if (reportError || !report) return json(request, { error: "Report not found" }, 404);

    const authorization = request.headers.get("Authorization") || "";
    let callerUserId = "";
    if (authorization) {
      const caller = createClient(supabaseUrl, anonKey, {
        auth: { persistSession: false },
        global: { headers: { Authorization: authorization } },
      });
      const { data } = await caller.auth.getUser();
      callerUserId = data.user?.id || "";
    }

    if (callerUserId) {
      const isGuestOwner = callerUserId === report.guest_user_id;
      let isPropertyStaff = false;
      if (!isGuestOwner) {
        const { data: staff } = await admin
          .from("property_staff")
          .select("property_id")
          .eq("property_id", report.property_id)
          .eq("user_id", callerUserId)
          .eq("active", true)
          .maybeSingle();
        isPropertyStaff = Boolean(staff);
      }
      if (!isGuestOwner && !isPropertyStaff) return json(request, { error: "Not authorised for this report" }, 403);
    } else if (requestOrigin || !report.escalated_at) {
      // The database escalation job has no user session and no browser Origin.
      // It may notify only reports that the database has already marked overdue.
      return json(request, { error: "A report owner or property staff session is required" }, 401);
    }

    const eventType = report.escalated_at ? "escalated" : "created";
    const { data: recipients, error: recipientsError } = await admin.rpc("notification_recipient_emails", {
      target_property_id: report.property_id,
      target_department_id: report.department_id,
    });
    if (recipientsError) return json(request, { error: "Recipients could not be resolved" }, 500);

    const emails = [...new Set((recipients || []).map((row: { email: string }) => row.email).filter(Boolean))];
    if (!emails.length) return json(request, { skipped: "no recipients configured" });
    if (!resendApiKey) return json(request, { skipped: "email provider not configured" });

    const { data: claimed, error: claimError } = await admin.rpc("claim_guest_report_notification", {
      p_report_id: reportId,
      p_event_type: eventType,
    });
    if (claimError) return json(request, { error: "Notification delivery could not be claimed" }, 500);
    if (!claimed) return json(request, { skipped: "notification already delivered or in progress" });

    const linkedProperty = Array.isArray(report.properties) ? report.properties[0] : report.properties;
    const propertyName = linkedProperty?.name || "InnRelay";
    const isEscalated = eventType === "escalated";
    const subject = `${isEscalated ? "[Overdue]" : "[New]"} ${propertyName} · ${report.location} · ${report.title}`;
    const html = `<p><strong>${escapeHtml(report.title)}</strong></p>` +
      `<p>${escapeHtml(report.location)} &middot; ${escapeHtml(report.category_label || "")}</p>` +
      `<p>${escapeHtml(report.description || "No additional detail supplied.")}</p>` +
      `<p>Urgency: ${escapeHtml(report.urgency)} &middot; Guest impact: ${escapeHtml(report.guest_impact)}</p>` +
      (isEscalated ? "<p><strong>This request is overdue and needs attention.</strong></p>" : "");

    const sendResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${resendApiKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({ from: "InnRelay <onboarding@resend.dev>", to: emails, subject, html }),
    });

    if (!sendResponse.ok) {
      await admin.rpc("complete_guest_report_notification", {
        p_report_id: reportId, p_event_type: eventType, p_succeeded: false,
        p_provider_id: null, p_error: `Provider returned ${sendResponse.status}`,
      });
      return json(request, { error: "Email provider rejected the notification" }, 502);
    }

    const providerResult = await sendResponse.json().catch(() => ({}));
    await admin.rpc("complete_guest_report_notification", {
      p_report_id: reportId, p_event_type: eventType, p_succeeded: true,
      p_provider_id: typeof providerResult.id === "string" ? providerResult.id : null, p_error: null,
    });
    return json(request, { sent: emails.length });
  } catch (error) {
    console.error("notify-guest-report failed", error instanceof Error ? error.message : "Unknown error");
    return json(request, { error: "Notification could not be processed" }, 500);
  }
});

