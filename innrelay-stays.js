(function () {
  "use strict";

  var config = window.INNRELAY_CONFIG || {};
  var catalog = window.InnRelayStaysCatalog;
  var client = null;
  var session = null;
  var memberships = [];
  var membership = null;
  var departments = [];
  var areas = [];
  var routes = [];
  var team = [];
  var invitations = [];
  var reports = [];
  var channel = null;
  var currentView = "dashboard";
  var toastTimer = null;

  function byId(id) { return document.getElementById(id); }
  function escapeHtml(value) {
    return String(value == null ? "" : value).replace(/[&<>"']/g, function (character) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#039;" }[character];
    });
  }
  function slugify(value) { return catalog.slugify(value); }
  function uuid() {
    if (window.crypto && typeof window.crypto.randomUUID === "function") return window.crypto.randomUUID();
    return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, function (character) {
      var random = Math.random() * 16 | 0;
      return (character === "x" ? random : (random & 3 | 8)).toString(16);
    });
  }
  function isManager() { return membership && ["owner", "manager"].indexOf(membership.role) >= 0; }
  function setConnection(message, state) {
    byId("connection").textContent = message;
    byId("connection").className = "connection" + (state ? " " + state : "");
  }
  function showToast(message) {
    var target = byId("toast");
    target.textContent = message;
    target.hidden = false;
    window.clearTimeout(toastTimer);
    toastTimer = window.setTimeout(function () { target.hidden = true; }, 4200);
  }
  function friendlyError(error, fallback) {
    var message = String(error && error.message || "");
    if (/row-level security|permission denied|42501/i.test(message)) return "Your account is not authorised to make that change for this Stay.";
    if (/duplicate key|23505/i.test(message)) return "That name or code is already used in this Stay.";
    if (/invalid input|check constraint|23514|22P02/i.test(message)) return "One of the details is not valid. Check the form and try again.";
    if (/Failed to fetch|NetworkError|Load failed/i.test(message)) return "InnRelay could not reach the service. Check your connection and try again.";
    return fallback || "The action could not be completed. Please try again.";
  }
  function formatDate(value) {
    try { return new Date(value).toLocaleString([], { dateStyle: "medium", timeStyle: "short" }); }
    catch (error) { return value || "Just now"; }
  }
  function statusLabel(value) {
    return { reported: "New", acknowledged: "Acknowledged", in_progress: "In progress", waiting_guest: "Waiting for guest", resolved: "Resolved", closed: "Closed", cancelled: "Cancelled", duplicate: "Duplicate" }[value] || String(value || "New").replace(/_/g, " ");
  }
  function publicStaffUrl() {
    return config.publicStaysUrl || new URL("./innrelay-stays.html", window.location.href).href;
  }
  function publicGuestBaseUrl() {
    return config.publicStaysGuestUrl || new URL("./innrelay-stays-guest.html", window.location.href).href;
  }
  function membershipProperty(row) {
    var property = Array.isArray(row.properties) ? row.properties[0] : row.properties;
    if (!property || property.property_type !== "short_term_rental") return null;
    return {
      property_id: row.property_id,
      department_id: row.department_id,
      display_name: row.display_name,
      role: row.role,
      property: property
    };
  }
  function selectedArea() {
    var id = byId("qr-area").value;
    return areas.filter(function (area) { return area.id === id; })[0] || null;
  }
  function buildGuestUrl(area) {
    if (!membership || !area) return "";
    var url = new URL(byId("qr-public-url").value || publicGuestBaseUrl(), window.location.href);
    url.search = "";
    url.hash = "/g/" + encodeURIComponent(membership.property.slug) + "/a/" + encodeURIComponent(area.code);
    url.searchParams.set("pid", membership.property.id);
    url.searchParams.set("lid", area.id);
    url.searchParams.set("p", membership.property.public_id);
    url.searchParams.set("l", area.public_id);
    return url.href;
  }
  function visibleGuestUrl(area) {
    if (!membership || !area) return "";
    var url = new URL(byId("qr-public-url").value || publicGuestBaseUrl(), window.location.href);
    return url.host + url.pathname + "#/g/" + membership.property.slug + "/a/" + area.code;
  }

  function showLanding() {
    byId("landing").hidden = false;
    byId("auth-screen").hidden = true;
    byId("app").hidden = true;
    byId("property-switcher-wrap").hidden = true;
    byId("open-guest-portal-top").hidden = true;
    byId("sign-out-top").hidden = true;
  }
  function showAuth() {
    byId("landing").hidden = true;
    byId("auth-screen").hidden = false;
    byId("app").hidden = true;
  }
  function showApp() {
    byId("landing").hidden = true;
    byId("auth-screen").hidden = true;
    byId("app").hidden = false;
    byId("sign-out-top").hidden = false;
    byId("sidebar-name").textContent = session && (session.user.user_metadata.full_name || session.user.user_metadata.name || session.user.email) || "Host team";
    byId("sidebar-email").textContent = session && session.user.email || "";
  }
  function showView(view) {
    currentView = view;
    Array.prototype.forEach.call(document.querySelectorAll("[data-view-panel]"), function (panel) {
      panel.hidden = panel.id !== view + "-view";
    });
    Array.prototype.forEach.call(document.querySelectorAll(".side-link[data-view]"), function (button) {
      button.classList.toggle("active", button.getAttribute("data-view") === view);
    });
    if (view === "qr") updateQrPreview();
  }

  function renderSwitcher() {
    var wrap = byId("property-switcher-wrap");
    var select = byId("property-switcher");
    if (!memberships.length) { wrap.hidden = true; select.innerHTML = ""; return; }
    wrap.hidden = false;
    select.innerHTML = memberships.map(function (item) {
      return '<option value="' + escapeHtml(item.property_id) + '"' + (membership && membership.property_id === item.property_id ? " selected" : "") + '>' + escapeHtml(item.property.name) + '</option>';
    }).join("");
  }

  function renderMetrics() {
    var now = Date.now();
    var open = reports.filter(function (report) { return ["resolved", "closed", "cancelled", "duplicate"].indexOf(report.status) < 0; });
    var overdue = open.filter(function (report) { return report.acknowledge_due_at && !report.acknowledged_at && new Date(report.acknowledge_due_at).getTime() < now; });
    var resolved = reports.filter(function (report) { return ["resolved", "closed"].indexOf(report.status) >= 0; });
    var suspected = reports.filter(function (report) { return ["suspected", "quarantined"].indexOf(report.moderation_status) >= 0; });
    var items = [["Open requests", open.length], ["Awaiting acknowledgement", overdue.length], ["Resolved", resolved.length], ["Abuse review", suspected.length]];
    byId("dashboard-metrics").innerHTML = items.map(function (item) { return '<article class="metric"><span>' + item[0] + '</span><strong>' + item[1] + '</strong></article>'; }).join("");
    renderEscalationBanner(overdue, suspected);
  }
  function renderEscalationBanner(overdue, quarantined) {
    var banner = byId("escalation-banner");
    if (!banner) return;
    var flagged = quarantined.filter(function (report) { return report.moderation_status === "quarantined"; });
    if (!overdue.length && !flagged.length) { banner.hidden = true; banner.textContent = ""; return; }
    var parts = [];
    if (overdue.length) parts.push(overdue.length + " request" + (overdue.length === 1 ? "" : "s") + " awaiting acknowledgement past target");
    if (flagged.length) parts.push(flagged.length + " flagged for review");
    banner.textContent = "⚠ " + parts.join(" · ") + " — this banner shows even if email notifications aren't set up yet.";
    banner.hidden = false;
  }
  function reportCard(report) {
    var suspected = ["suspected", "quarantined"].indexOf(report.moderation_status) >= 0;
    var department = departments.filter(function (item) { return item.id === report.department_id; })[0];
    var closed = ["resolved", "closed", "cancelled", "duplicate"].indexOf(report.status) >= 0;
    var actions = closed ? "" : '<div class="report-actions"><input class="report-note" data-report-note placeholder="Update visible to the guest or resolution note"><button class="button button-small button-quiet" data-report-action="acknowledged" type="button">Acknowledge</button><button class="button button-small button-primary" data-report-action="in_progress" type="button">Start work</button><button class="button button-small button-sun" data-report-action="resolved" type="button">Resolve</button></div>';
    return '<article class="report-card' + (suspected ? " suspected" : "") + '" data-report-id="' + escapeHtml(report.id) + '">' +
      '<div class="report-top"><div><span class="report-kicker">' + escapeHtml(report.location) + ' · ' + escapeHtml(report.category_label) + '</span><h3>' + escapeHtml(report.title) + '</h3></div><span class="status-pill ' + escapeHtml(report.status) + '">' + escapeHtml(statusLabel(report.status)) + '</span></div>' +
      '<p>' + escapeHtml(report.description || "No additional detail supplied.") + '</p>' +
      '<div class="report-meta"><span>' + escapeHtml(report.guest_name || "Guest") + '</span><span>' + escapeHtml(department ? department.name : "Unassigned") + '</span><span>' + escapeHtml(formatDate(report.created_at)) + '</span>' + (report.escalated_at ? '<span>Escalated</span>' : '') + (suspected ? '<span>Flagged for abuse review</span>' : '') + '</div>' +
      (report.staff_note ? '<p><strong>Latest host update:</strong> ' + escapeHtml(report.staff_note) + '</p>' : '') + actions + '</article>';
  }
  function renderReports() {
    var ordered = reports.slice().sort(function (a, b) { return new Date(b.created_at) - new Date(a.created_at); });
    var open = ordered.filter(function (report) { return ["resolved", "closed", "cancelled", "duplicate"].indexOf(report.status) < 0; });
    byId("dashboard-reports").innerHTML = open.length ? open.slice(0, 8).map(reportCard).join("") : '<div class="empty">No open requests for this Stay.</div>';
    byId("inbox-list").innerHTML = ordered.length ? ordered.map(reportCard).join("") : '<div class="empty">No guest requests yet. Test a real area QR to complete the flow.</div>';
    byId("inbox-count").textContent = ordered.length + " total · " + open.length + " open";
    renderMetrics();
  }

  function areaIcon(type) {
    return { entrance: "↪", living: "⌂", kitchen: "◫", bathroom: "≈", bedroom: "▰", dining: "◌", laundry: "↻", workspace: "⌨", outdoor: "☀", parking: "P", pool_hot_tub: "≈", shared_area: "◇", whole_property: "⌂", other: "·" }[type] || "·";
  }
  function renderAreas() {
    var active = areas.filter(function (area) { return area.active; });
    byId("area-list").innerHTML = areas.length ? areas.map(function (area) {
      var department = departments.filter(function (item) { return item.id === area.department_id; })[0];
      return '<article class="area-card"><span class="area-icon">' + areaIcon(area.location_type) + '</span><h3>' + escapeHtml(area.name) + '</h3><p>' + escapeHtml(area.location_type.replace(/_/g, " ")) + (department ? " · " + escapeHtml(department.name) : "") + '</p><div class="list-actions"><span class="status-pill ' + (area.active ? "active" : "disabled") + '">' + (area.active ? "Active" : "Disabled") + '</span>' + (isManager() ? '<button class="button button-quiet button-small" data-area-toggle="' + escapeHtml(area.id) + '" data-active="' + area.active + '" type="button">' + (area.active ? "Disable" : "Activate") + '</button>' : '') + '</div></article>';
    }).join("") : '<div class="empty">No Stay areas yet. Add the standard areas to begin.</div>';
    var options = active.map(function (area) { return '<option value="' + escapeHtml(area.id) + '">' + escapeHtml(area.name) + '</option>'; }).join("");
    var previous = byId("qr-area").value;
    byId("qr-area").innerHTML = options || '<option value="">No active areas</option>';
    if (active.some(function (area) { return area.id === previous; })) byId("qr-area").value = previous;
    updateQrPreview();
  }
  function setDepartmentOptions() {
    var options = departments.filter(function (department) { return department.active; }).map(function (department) {
      return '<option value="' + escapeHtml(department.id) + '">' + escapeHtml(department.name) + '</option>';
    }).join("");
    byId("area-department").innerHTML = '<option value="">No default team</option>' + options;
    byId("invite-department").innerHTML = '<option value="">All teams</option>' + options;
  }
  function renderDepartments() {
    byId("department-list").innerHTML = departments.length ? departments.map(function (department) {
      return '<div class="list-row"><div><strong>' + escapeHtml(department.name) + '</strong><small>Acknowledge ' + department.response_target_minutes + ' min · escalate ' + department.escalation_minutes + ' min</small></div><div class="list-actions"><span class="status-pill ' + (department.active ? "active" : "disabled") + '">' + (department.active ? "Active" : "Disabled") + '</span>' + (isManager() ? '<button class="button button-quiet button-small" data-department-toggle="' + escapeHtml(department.id) + '" data-active="' + department.active + '" type="button">' + (department.active ? "Disable" : "Activate") + '</button>' : '') + '</div></div>';
    }).join("") : '<div class="empty">No host teams configured.</div>';
    setDepartmentOptions();
  }
  function renderRoutes() {
    byId("catalogue-stat").textContent = catalog.stats.categories + " Stays categories · " + catalog.stats.issues + " guest needs";
    var activeDepartments = departments.filter(function (department) { return department.active; });
    byId("route-list").innerHTML = catalog.categories.map(function (category) {
      var route = routes.filter(function (item) { return item.category_key === category.key; })[0];
      var options = '<option value="">Choose host team</option>' + activeDepartments.map(function (department) {
        return '<option value="' + escapeHtml(department.id) + '"' + (route && route.department_id === department.id ? " selected" : "") + '>' + escapeHtml(department.name) + '</option>';
      }).join("");
      return '<div class="route-row"><div><strong>' + escapeHtml(category.label) + '</strong><span>' + escapeHtml(category.group) + (category.emergency ? " · call-first safety category" : "") + '</span></div><select data-route-category="' + escapeHtml(category.key) + '"' + (isManager() ? "" : " disabled") + '>' + options + '</select></div>';
    }).join("");
  }
  function renderTeam() {
    byId("team-list").innerHTML = team.length ? team.map(function (person) {
      var department = departments.filter(function (item) { return item.id === person.department_id; })[0];
      return '<div class="list-row"><div><strong>' + escapeHtml(person.display_name) + '</strong><small>' + escapeHtml(department ? department.name : "All teams") + '</small></div><span class="role-pill">' + escapeHtml(person.role) + '</span></div>';
    }).join("") : '<div class="empty">No active host-team members.</div>';
    byId("invitation-list").innerHTML = invitations.length ? invitations.map(function (invitation) {
      var invitationUrl = new URL(publicStaffUrl());
      invitationUrl.searchParams.set("invite", invitation.token);
      return '<div class="list-row"><div><strong>' + escapeHtml(invitation.email) + '</strong><small>' + escapeHtml(invitation.role) + ' · expires ' + escapeHtml(formatDate(invitation.expires_at)) + '</small></div><button class="button button-quiet button-small" data-copy-invite="' + escapeHtml(invitationUrl.href) + '" type="button">Copy link</button></div>';
    }).join("") : '<div class="empty">No pending invitations.</div>';
  }
  function renderSettings() {
    if (!membership) return;
    var property = membership.property;
    byId("settings-name").value = property.name || "";
    byId("settings-address").value = property.address || "";
    byId("settings-contact").value = property.reception_phone || "";
    byId("settings-colour").value = property.brand_colour || "#2f8068";
    byId("settings-retention").value = String(property.data_retention_days || 90);
    document.documentElement.style.setProperty("--brand", property.brand_colour || "#2f8068");
  }

  function renderPermissions() {
    var manager = isManager();
    ["area-form", "department-form", "invite-form", "settings-form", "create-another-stay"].forEach(function (id) {
      byId(id).hidden = !manager;
    });
    var settingsNavigation = document.querySelector('.side-link[data-view="settings"]');
    if (settingsNavigation) settingsNavigation.hidden = !manager;
    if (!manager && currentView === "settings") showView("dashboard");
  }

  async function loadReports() {
    if (!client || !membership) return;
    var result = await client.from("guest_reports")
      .select("id,property_id,location_id,department_id,location,category_key,category_label,issue_code,title,description,urgency,guest_impact,guest_name,contact_preference,status,owner_user_id,owner_display,staff_note,resolution_note,acknowledged_at,resolved_at,acknowledge_due_at,escalation_due_at,escalated_at,moderation_status,moderation_reason,abuse_score,created_at,updated_at")
      .eq("property_id", membership.property_id).order("created_at", { ascending: false }).limit(300);
    if (result.error) { setConnection(friendlyError(result.error, "Guest requests could not be loaded."), "error"); return; }
    reports = result.data || [];
    renderReports();
  }
  async function loadConfiguration() {
    if (!client || !membership) return;
    var queryList = [
      client.from("property_departments").select("id,property_id,name,code,response_target_minutes,escalation_minutes,active").eq("property_id", membership.property_id).order("name"),
      client.from("property_locations").select("id,property_id,department_id,public_id,name,code,location_type,floor,allows_guest_correction,active,sort_order").eq("property_id", membership.property_id).order("sort_order").order("name"),
      client.from("department_routes").select("property_id,category_key,department_id").eq("property_id", membership.property_id).order("category_key"),
      client.from("property_staff").select("property_id,user_id,department_id,display_name,role,active").eq("property_id", membership.property_id).eq("active", true).order("display_name")
    ];
    if (isManager()) queryList.push(client.from("property_invitations").select("id,property_id,department_id,token,email,role,active,expires_at,accepted_at,created_at").eq("property_id", membership.property_id).eq("active", true).is("accepted_at", null).order("created_at", { ascending: false }));
    var results = await Promise.all(queryList);
    var failed = results.filter(function (result) { return result.error; })[0];
    if (failed) { setConnection(friendlyError(failed.error, "The Stay configuration could not be loaded."), "error"); return; }
    departments = results[0].data || [];
    areas = (results[1].data || []).filter(function (area) { return area.location_type !== "room" && ["reception", "bar", "restaurant", "gym"].indexOf(area.location_type) < 0; });
    routes = results[2].data || [];
    team = results[3].data || [];
    invitations = isManager() && results[4] ? results[4].data || [] : [];
    renderPermissions(); renderAreas(); renderDepartments(); renderRoutes(); renderTeam(); renderSettings();
    byId("qr-public-url").value = config.publicStaysGuestUrl || publicGuestBaseUrl();
  }

  async function activateMembership(next) {
    if (!next) return;
    if (channel) await client.removeChannel(channel);
    membership = next;
    try { window.localStorage.setItem("innrelay-stays-active-property", next.property_id); } catch (error) {}
    renderSwitcher();
    byId("onboarding").hidden = true;
    Array.prototype.forEach.call(document.querySelectorAll("[data-view-panel]"), function (panel) { panel.hidden = true; });
    showView(currentView || "dashboard");
    byId("open-guest-portal-top").hidden = false;
    setConnection("Live · connected to " + membership.property.name + " · InnRelay Stays", "live");
    await loadConfiguration();
    await loadReports();
    channel = client.channel("stays-reports-" + membership.property_id).on("postgres_changes", {
      event: "*", schema: "public", table: "guest_reports", filter: "property_id=eq." + membership.property_id
    }, function () { loadReports(); }).subscribe();
  }

  async function acceptInvite() {
    var token = new URLSearchParams(window.location.search).get("invite");
    if (!token || !session) return;
    var verticalResult = await client.rpc("invitation_vertical", { p_token: token });
    if (verticalResult.error || verticalResult.data !== "short_term_rental") {
      setConnection("This Stays invitation is invalid, expired or belongs to another InnRelay product.", "error"); return;
    }
    var invitationResult = await client.from("property_invitations").select("id,property_id,department_id,email,role,active,expires_at,accepted_at").eq("token", token).maybeSingle();
    var invitation = invitationResult.data;
    if (invitationResult.error || !invitation) {
      setConnection("This Stays invitation is invalid, expired or belongs to another InnRelay product.", "error"); return;
    }
    var metadata = session.user.user_metadata || {};
    var result = await client.from("property_staff").insert({
      property_id: invitation.property_id, user_id: session.user.id, department_id: invitation.department_id,
      display_name: String(metadata.full_name || metadata.name || session.user.email || "Host team").slice(0, 100),
      role: invitation.role, invite_id: invitation.id, active: true
    });
    if (result.error && result.error.code !== "23505") { setConnection(friendlyError(result.error, "The invitation could not be accepted."), "error"); return; }
    var clean = new URL(window.location.href); clean.searchParams.delete("invite");
    window.history.replaceState({}, document.title, clean.pathname + clean.search + clean.hash);
    showToast("Stays invitation accepted.");
  }

  async function loadMemberships() {
    var result = await client.from("property_staff")
      .select("property_id,department_id,display_name,role,active,properties!inner(id,name,slug,public_id,reception_phone,emergency_notice,brand_colour,timezone,address,guest_welcome,data_retention_days,property_type,active)")
      .eq("user_id", session.user.id).eq("active", true);
    if (result.error) { setConnection(friendlyError(result.error, "Your Stays memberships could not be loaded."), "error"); return; }
    memberships = (result.data || []).map(membershipProperty).filter(Boolean).filter(function (item) { return item.property.active; });
    if (!memberships.length) {
      membership = null; showApp(); renderSwitcher(); byId("onboarding").hidden = false;
      Array.prototype.forEach.call(document.querySelectorAll("[data-view-panel]"), function (panel) { panel.hidden = true; });
      setConnection("Google account connected · create your first private Stays workspace.", "live");
      return;
    }
    var saved = ""; try { saved = window.localStorage.getItem("innrelay-stays-active-property") || ""; } catch (error) {}
    var preferred = memberships.filter(function (item) { return item.property_id === saved; })[0] || memberships[0];
    showApp(); await activateMembership(preferred);
  }

  async function handleSession(nextSession) {
    session = nextSession || null;
    if (!session) { memberships = []; membership = null; showLanding(); return; }
    showApp();
    await acceptInvite();
    await loadMemberships();
  }

  async function updateReport(reportId, status, note) {
    var patch = { status: status, staff_note: note || null, owner_user_id: session.user.id, owner_display: membership.display_name };
    if (status === "acknowledged" || status === "in_progress") patch.acknowledged_at = new Date().toISOString();
    if (status === "resolved") { patch.resolved_at = new Date().toISOString(); patch.resolution_note = note || "The host team has marked this request resolved."; }
    var result = await client.from("guest_reports").update(patch).eq("id", reportId).eq("property_id", membership.property_id).select("id").single();
    if (result.error) { showToast(friendlyError(result.error, "The request could not be updated.")); return; }
    await client.from("guest_report_updates").insert({ report_id: reportId, author_user_id: session.user.id, author_kind: "staff", message: note || (status === "resolved" ? "Resolved by the host team." : "The host team is working on this request."), status: status });
    await loadReports();
    showToast(status === "resolved" ? "Request resolved." : "Guest request updated.");
  }

  async function updateQrPreview() {
    var area = selectedArea();
    var image = byId("qr-image");
    if (!area || !membership || !window.InnRelayQRCode) {
      image.removeAttribute("src"); byId("qr-area-name").textContent = "Choose an area"; byId("qr-visible-url").textContent = "Trusted URL appears here"; return;
    }
    try {
      image.src = await window.InnRelayQRCode.toSvgDataUrl(buildGuestUrl(area), 320);
      byId("qr-area-name").textContent = membership.property.name + " · " + area.name;
      byId("qr-visible-url").textContent = visibleGuestUrl(area);
      byId("open-guest-portal-top").href = buildGuestUrl(area);
    } catch (error) { showToast("The QR preview could not be generated."); }
  }
  function svgDataUrlToPng(source, size) {
    return new Promise(function (resolve, reject) {
      var image = new Image();
      image.onload = function () {
        var canvas = document.createElement("canvas"); canvas.width = size; canvas.height = size;
        var context = canvas.getContext("2d"); context.fillStyle = "#ffffff"; context.fillRect(0, 0, size, size); context.drawImage(image, 0, 0, size, size);
        resolve(canvas.toDataURL("image/png"));
      };
      image.onerror = reject; image.src = source;
    });
  }
  async function openQrPdf() {
    var activeAreas = areas.filter(function (area) { return area.active; });
    if (!membership || !activeAreas.length || !window.jspdf || !window.jspdf.jsPDF) { showToast("Add at least one active area before creating the PDF."); return; }
    var button = byId("download-all-qr"); button.disabled = true; button.textContent = "Building PDF…";
    try {
      var pdf = new window.jspdf.jsPDF({ orientation: "portrait", unit: "mm", format: "a4" });
      var cardWidth = 88, cardHeight = 128, left = 11, top = 14, gapX = 12, gapY = 10;
      for (var index = 0; index < activeAreas.length; index += 1) {
        if (index && index % 4 === 0) pdf.addPage();
        var position = index % 4, col = position % 2, row = Math.floor(position / 2);
        var x = left + col * (cardWidth + gapX), y = top + row * (cardHeight + gapY), area = activeAreas[index];
        var svg = await window.InnRelayQRCode.toSvgDataUrl(buildGuestUrl(area), 500);
        var png = await svgDataUrlToPng(svg, 500);
        pdf.setDrawColor(180, 194, 185); pdf.roundedRect(x, y, cardWidth, cardHeight, 4, 4);
        pdf.setTextColor(16, 37, 31); pdf.setFont("helvetica", "bold"); pdf.setFontSize(11); pdf.text("InnRelay Stays", x + cardWidth / 2, y + 9, { align: "center" });
        pdf.setFontSize(13); pdf.text(membership.property.name, x + cardWidth / 2, y + 17, { align: "center", maxWidth: cardWidth - 10 });
        pdf.setFontSize(15); pdf.text(area.name, x + cardWidth / 2, y + 26, { align: "center", maxWidth: cardWidth - 10 });
        pdf.addImage(png, "PNG", x + 17, y + 31, 54, 54);
        pdf.setFont("helvetica", "normal"); pdf.setFontSize(7.4); pdf.setTextColor(49, 81, 72); pdf.text(visibleGuestUrl(area), x + cardWidth / 2, y + 91, { align: "center", maxWidth: cardWidth - 10 });
        pdf.setFont("helvetica", "bold"); pdf.setFontSize(8.4); pdf.setTextColor(16, 37, 31); pdf.text("Scan for help with your stay", x + cardWidth / 2, y + 102, { align: "center" });
        pdf.setFont("helvetica", "normal"); pdf.setFontSize(7.5); pdf.text("No account or app required.", x + cardWidth / 2, y + 108, { align: "center" });
        pdf.setFillColor(255, 241, 210); pdf.roundedRect(x + 7, y + 113, cardWidth - 14, 10, 2, 2, "F");
        pdf.setFont("helvetica", "bold"); pdf.setTextColor(105, 64, 25); pdf.setFontSize(7.2); pdf.text("No payments · no passwords · no app download", x + cardWidth / 2, y + 119, { align: "center", maxWidth: cardWidth - 18 });
      }
      var blobUrl = URL.createObjectURL(pdf.output("blob"));
      var opened = window.open(blobUrl, "_blank", "noopener");
      if (!opened) { var anchor = document.createElement("a"); anchor.href = blobUrl; anchor.download = slugify(membership.property.name) + "-innrelay-stays-qr-cards.pdf"; anchor.click(); }
      window.setTimeout(function () { URL.revokeObjectURL(blobUrl); }, 120000);
      showToast("A4 QR PDF opened with print and download controls.");
    } catch (error) { showToast("The QR PDF could not be created. Check the public guest URL and try again."); }
    finally { button.disabled = false; button.textContent = "Open A4 QR PDF"; }
  }

  async function initialise() {
    if (!catalog || !window.supabase || !config.supabaseUrl || !config.supabasePublishableKey) {
      byId("auth-status").textContent = "The Stays portal is missing its public Supabase configuration."; showAuth(); return;
    }
    client = window.supabase.createClient(config.supabaseUrl, config.supabasePublishableKey, {
      auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true, storageKey: "innrelay-stays-staff-auth" }
    });
    client.auth.onAuthStateChange(function (event, authSession) { window.setTimeout(function () { handleSession(authSession); }, 0); });
    var result = await client.auth.getSession();
    if (result.error) { byId("auth-status").textContent = friendlyError(result.error, "Sign-in could not be restored."); showAuth(); return; }
    await handleSession(result.data.session);
  }

  byId("start-stays").addEventListener("click", function () { if (session) showApp(); else showAuth(); });
  byId("back-to-landing").addEventListener("click", showLanding);
  byId("google-sign-in").addEventListener("click", async function () {
    byId("google-sign-in").disabled = true; byId("auth-status").textContent = "Opening Google sign-in…";
    var redirect = new URL(publicStaffUrl()); redirect.searchParams.delete("error"); redirect.searchParams.delete("error_description");
    var result = await client.auth.signInWithOAuth({ provider: "google", options: { redirectTo: redirect.href, queryParams: { prompt: "select_account" } } });
    if (result.error) { byId("auth-status").textContent = friendlyError(result.error, "Google sign-in could not be started."); byId("google-sign-in").disabled = false; }
  });
  async function signOut() { if (channel) await client.removeChannel(channel); await client.auth.signOut(); showLanding(); }
  byId("sign-out-top").addEventListener("click", signOut);
  Array.prototype.forEach.call(document.querySelectorAll("[data-view]"), function (button) { button.addEventListener("click", function () { showView(button.getAttribute("data-view")); }); });
  byId("property-switcher").addEventListener("change", function () { var next = memberships.filter(function (item) { return item.property_id === byId("property-switcher").value; })[0]; if (next) activateMembership(next); });
  byId("refresh-dashboard").addEventListener("click", loadReports);
  byId("refresh-inbox").addEventListener("click", loadReports);
  byId("inbox-list").addEventListener("click", function (event) {
    var button = event.target.closest("[data-report-action]"); if (!button) return;
    var card = button.closest("[data-report-id]"); var note = card.querySelector("[data-report-note]").value.trim();
    updateReport(card.getAttribute("data-report-id"), button.getAttribute("data-report-action"), note);
  });
  byId("dashboard-reports").addEventListener("click", function (event) {
    var button = event.target.closest("[data-report-action]"); if (!button) return;
    var card = button.closest("[data-report-id]"); var note = card.querySelector("[data-report-note]").value.trim();
    updateReport(card.getAttribute("data-report-id"), button.getAttribute("data-report-action"), note);
  });
  byId("onboard-name").addEventListener("input", function () { if (!byId("onboard-slug").dataset.edited) byId("onboard-slug").value = slugify(this.value); });
  byId("onboard-slug").addEventListener("input", function () { this.dataset.edited = this.value ? "true" : ""; this.value = slugify(this.value); });
  byId("onboarding-form").addEventListener("submit", async function (event) {
    event.preventDefault(); var submit = event.submitter; submit.disabled = true;
    var payload = { name: byId("onboard-name").value.trim(), slug: slugify(byId("onboard-slug").value), address: byId("onboard-address").value.trim() || null, guest_contact: byId("onboard-contact").value.trim() || null, brand_colour: byId("onboard-colour").value };
    var result = await client.rpc("create_stays_workspace", { p_payload: payload });
    if (result.error) { setConnection(friendlyError(result.error, "The Stays workspace could not be created."), "error"); submit.disabled = false; return; }
    try { window.localStorage.setItem("innrelay-stays-active-property", Array.isArray(result.data) ? result.data[0] : result.data); } catch (error) {}
    event.target.reset(); byId("onboard-colour").value = "#2f8068"; byId("onboard-slug").dataset.edited = ""; submit.disabled = false;
    showToast("InnRelay Stays workspace created."); await loadMemberships(); showView("areas");
  });
  byId("create-another-stay").addEventListener("click", function () { byId("onboarding").hidden = false; Array.prototype.forEach.call(document.querySelectorAll("[data-view-panel]"), function (panel) { panel.hidden = true; }); });
  byId("area-name").addEventListener("input", function () { this.dataset.code = slugify(this.value); });
  byId("area-form").addEventListener("submit", async function (event) {
    event.preventDefault(); if (!isManager()) { showToast("Only an owner or manager can add Stay areas."); return; }
    var result = await client.rpc("create_stays_area", { p_property_id: membership.property_id, p_payload: { department_id: byId("area-department").value || null, name: byId("area-name").value.trim(), code: slugify(byId("area-name").value), location_type: byId("area-type").value, sort_order: areas.length * 10 + 10 } });
    if (result.error) { showToast(friendlyError(result.error, "The area could not be added.")); return; }
    event.target.reset(); await loadConfiguration(); showToast("Stay area added.");
  });
  byId("seed-standard-areas").addEventListener("click", async function () {
    if (!isManager()) { showToast("Only an owner or manager can add Stay areas."); return; }
    var missing = catalog.defaultAreas.filter(function (seed) { return !areas.some(function (area) { return area.code === seed.code; }); });
    if (!missing.length) { showToast("All standard Stay areas already exist."); return; }
    var results = await Promise.all(missing.map(function (seed) {
      var department = departments.filter(function (item) { return item.code === seed.route; })[0];
      return client.rpc("create_stays_area", { p_property_id: membership.property_id, p_payload: { department_id: department ? department.id : null, name: seed.name, code: seed.code, location_type: seed.type, sort_order: seed.order } });
    }));
    var failed = results.filter(function (result) { return result.error; })[0];
    if (failed) { showToast(friendlyError(failed.error, "Some standard areas could not be added.")); await loadConfiguration(); return; }
    await loadConfiguration(); showToast(missing.length + " standard Stay areas added.");
  });
  byId("area-list").addEventListener("click", async function (event) {
    var button = event.target.closest("[data-area-toggle]"); if (!button || !isManager()) return;
    var next = button.getAttribute("data-active") !== "true"; var result = await client.from("property_locations").update({ active: next }).eq("id", button.getAttribute("data-area-toggle")).eq("property_id", membership.property_id).select("id").single();
    if (result.error) { showToast(friendlyError(result.error, "The area status could not be changed.")); return; }
    await loadConfiguration(); showToast(next ? "Stay area activated." : "Stay area disabled.");
  });
  byId("qr-area").addEventListener("change", updateQrPreview);
  byId("qr-public-url").addEventListener("input", updateQrPreview);
  byId("update-qr").addEventListener("click", updateQrPreview);
  byId("open-selected-qr").addEventListener("click", function () { var area = selectedArea(); if (!area) return; window.open(buildGuestUrl(area), "_blank", "noopener"); });
  byId("download-all-qr").addEventListener("click", openQrPdf);
  byId("department-form").addEventListener("submit", async function (event) {
    event.preventDefault(); if (!isManager()) return;
    var target = Number(byId("department-target").value || 10); var result = await client.from("property_departments").insert({ property_id: membership.property_id, name: byId("department-name").value.trim(), code: slugify(byId("department-name").value), response_target_minutes: target, escalation_minutes: Math.min(1440, Math.max(target + 1, target * 2)) });
    if (result.error) { showToast(friendlyError(result.error, "The host team could not be added.")); return; }
    event.target.reset(); byId("department-target").value = "10"; await loadConfiguration(); showToast("Host team added.");
  });
  byId("department-list").addEventListener("click", async function (event) {
    var button = event.target.closest("[data-department-toggle]"); if (!button || !isManager()) return;
    var next = button.getAttribute("data-active") !== "true"; var result = await client.from("property_departments").update({ active: next }).eq("id", button.getAttribute("data-department-toggle")).eq("property_id", membership.property_id).select("id").single();
    if (result.error) { showToast(friendlyError(result.error, "The host-team status could not be changed.")); return; }
    await loadConfiguration(); showToast(next ? "Host team activated." : "Host team disabled.");
  });
  byId("route-list").addEventListener("change", async function (event) {
    var select = event.target.closest("[data-route-category]"); if (!select || !select.value || !isManager()) return;
    var result = await client.from("department_routes").upsert({ property_id: membership.property_id, category_key: select.getAttribute("data-route-category"), department_id: select.value }, { onConflict: "property_id,category_key" });
    if (result.error) { showToast(friendlyError(result.error, "The category route could not be saved.")); return; }
    await loadConfiguration(); showToast("Stays category route saved.");
  });
  byId("invite-form").addEventListener("submit", async function (event) {
    event.preventDefault(); if (!isManager()) return;
    var result = await client.from("property_invitations").insert({ property_id: membership.property_id, department_id: byId("invite-department").value || null, email: byId("invite-email").value.trim().toLowerCase(), role: byId("invite-role").value, invited_by: session.user.id, expires_at: new Date(Date.now() + 7 * 86400000).toISOString() });
    if (result.error) { showToast(friendlyError(result.error, "The host-team invitation could not be created.")); return; }
    event.target.reset(); await loadConfiguration(); showToast("Host-team invitation created.");
  });
  byId("invitation-list").addEventListener("click", async function (event) {
    var button = event.target.closest("[data-copy-invite]"); if (!button) return;
    try { await navigator.clipboard.writeText(button.getAttribute("data-copy-invite")); showToast("Invitation link copied."); }
    catch (error) { window.prompt("Copy this Stays invitation link:", button.getAttribute("data-copy-invite")); }
  });
  byId("settings-form").addEventListener("submit", async function (event) {
    event.preventDefault(); if (!isManager()) return;
    var result = await client.from("properties").update({ name: byId("settings-name").value.trim(), address: byId("settings-address").value.trim() || null, reception_phone: byId("settings-contact").value.trim() || null, brand_colour: byId("settings-colour").value, data_retention_days: Number(byId("settings-retention").value) }).eq("id", membership.property_id).eq("property_type", "short_term_rental").select("id").single();
    if (result.error) { showToast(friendlyError(result.error, "The Stay settings could not be saved.")); return; }
    showToast("Stay settings saved."); await loadMemberships(); showView("settings");
  });

  if ("serviceWorker" in navigator && window.location.protocol !== "file:") {
    navigator.serviceWorker.register("./innrelay-service-worker.js").catch(function () {});
  }

  initialise();
}());
