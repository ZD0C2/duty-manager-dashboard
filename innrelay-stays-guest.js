(function () {
  "use strict";

  var config = window.INNRELAY_CONFIG || {};
  var catalog = window.InnRelayStaysCatalog;
  var params = new URLSearchParams(window.location.search);
  var client = null;
  var user = null;
  var property = null;
  var scannedLocationId = null;
  var propertyToken = null;
  var locations = [];
  var selectedLocation = null;
  var channel = null;
  var turnstileWidgetId = null;
  var emergencyAcknowledged = false;
  var idempotencyKey = newIdempotencyKey();

  function byId(id) { return document.getElementById(id); }
  function escapeHtml(value) {
    return String(value == null ? "" : value).replace(/[&<>"']/g, function (character) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#039;" }[character];
    });
  }
  function newIdempotencyKey() {
    if (window.crypto && typeof window.crypto.randomUUID === "function") return window.crypto.randomUUID();
    return Date.now().toString(36) + "-" + Math.random().toString(36).slice(2) + "-stay";
  }
  function setConnection(message, state) {
    byId("connection").textContent = message;
    byId("connection").className = "connection" + (state ? " " + state : "");
  }
  function friendlyError(error, fallback) {
    var message = String(error && error.message || "");
    if (/too many requests|unusually high activity|temporarily limiting/i.test(message)) return message;
    if (/valid InnRelay QR|secure guest session|not valid for the selected/i.test(message)) return "This Stay QR session is no longer valid. Scan the printed InnRelay Stays card again.";
    if (/category|request type|issue/i.test(message) && /valid|choose/i.test(message)) return "Choose a listed Stay category and request, then try again.";
    if (/Failed to fetch|NetworkError|Load failed/i.test(message)) return "The request could not reach the host team. Check your connection and try again.";
    return fallback || "The request could not be sent. Please try again or contact the host team directly.";
  }
  function formatDate(value) {
    try { return new Date(value).toLocaleString([], { dateStyle: "medium", timeStyle: "short" }); }
    catch (error) { return value || "Just now"; }
  }
  function statusLabel(value) {
    return { reported: "Sent", acknowledged: "Acknowledged", in_progress: "In progress", waiting_guest: "Needs your reply", resolved: "Resolved", closed: "Closed", cancelled: "Cancelled", duplicate: "Combined" }[value] || "Sent";
  }
  function currentCategory() { return catalog.findCategory(byId("category").value); }
  function currentIssue() { return byId("issue").value; }
  function isEmergencyCategory() { var category = currentCategory(); return Boolean(category && category.emergency); }

  function waitForTurnstile() {
    return new Promise(function (resolve, reject) {
      var started = Date.now();
      (function check() {
        if (window.turnstile && typeof window.turnstile.render === "function") { resolve(window.turnstile); return; }
        if (Date.now() - started > 15000) { reject(new Error("Security check could not load")); return; }
        window.setTimeout(check, 100);
      }());
    });
  }
  async function requestTurnstileToken() {
    var siteKey = String(config.turnstileSiteKey || "").trim();
    if (!siteKey) throw new Error("The guest security check is not configured.");
    var panel = byId("verification"), status = byId("turnstile-status"), retry = byId("turnstile-retry");
    panel.hidden = false; retry.hidden = true; status.textContent = "Complete the quick verification to continue.";
    var api = await waitForTurnstile();
    return new Promise(function (resolve, reject) {
      try {
        turnstileWidgetId = api.render("#turnstile-widget", {
          sitekey: siteKey, theme: "light", size: "flexible", action: "stays_anonymous_signin",
          callback: function (token) { status.textContent = "Verified. Opening this Stay…"; resolve(token); },
          "expired-callback": function () { status.textContent = "Verification expired. Complete it again."; api.reset(turnstileWidgetId); },
          "error-callback": function () { status.textContent = "Verification failed. Check your connection and try again."; retry.hidden = false; reject(new Error("Security check failed")); }
        });
      } catch (error) { retry.hidden = false; reject(error); }
    });
  }

  function portalCredentials() {
    return { propertyId: params.get("pid"), locationId: params.get("lid"), propertyToken: params.get("p"), locationToken: params.get("l") };
  }
  function hotelGuestUrl() {
    var target = new URL(config.publicGuestUrl || "./innrelay-guest.html", window.location.href);
    target.search = window.location.search;
    target.hash = window.location.hash;
    return target.href;
  }
  async function claimLocation(location) {
    if (!location || !client || !user || !property || !propertyToken) return;
    var result = await client.from("guest_portal_sessions").upsert({
      user_id: user.id, property_id: property.id, location_id: location.id,
      property_token: propertyToken, location_token: location.public_id,
      expires_at: new Date(Date.now() + 8 * 86400000).toISOString(), last_seen_at: new Date().toISOString()
    }, { onConflict: "user_id,property_id,location_id" });
    if (result.error) throw result.error;
  }
  async function selectLocation(location, persist) {
    if (!location) return;
    selectedLocation = location;
    byId("area-display").textContent = location.name;
    renderAreaChips();
    if (persist !== false) {
      try { await claimLocation(location); }
      catch (error) { setConnection(friendlyError(error, "That area could not be selected."), "error"); }
    }
  }
  function renderAreaChips() {
    byId("area-chips").innerHTML = locations.map(function (location) {
      return '<button class="area-chip' + (selectedLocation && selectedLocation.id === location.id ? " active" : "") + '" type="button" data-location-id="' + escapeHtml(location.id) + '">' + escapeHtml(location.name) + '</button>';
    }).join("") || '<span class="field-note">No active areas are configured for this Stay.</span>';
  }

  function renderPopular() {
    var keys = ["str-checkin-access", "str-locks-keys-security", "str-wifi-tv-technology", "str-heating-cooling-air", "str-bathroom-water", "str-cleaning-maintenance"];
    byId("popular-categories").innerHTML = keys.map(function (key) {
      var category = catalog.findCategory(key);
      return category ? '<button class="category-tile" type="button" data-category-key="' + escapeHtml(key) + '">' + escapeHtml(category.label) + '</button>' : "";
    }).join("");
  }
  function populateCategories() {
    byId("category").innerHTML = catalog.categories.map(function (category) { return '<option value="' + escapeHtml(category.key) + '">' + escapeHtml(category.label) + '</option>'; }).join("");
    var requested = params.get("category"); if (requested && catalog.findCategory(requested)) byId("category").value = requested;
    populateIssues();
  }
  function populateIssues(selected) {
    var category = currentCategory();
    var rows = category ? category.issues.slice() : [];
    rows.push("Other / something else");
    byId("issue").innerHTML = rows.map(function (label) { return '<option value="' + escapeHtml(label) + '">' + escapeHtml(label) + '</option>'; }).join("");
    if (selected && rows.indexOf(selected) >= 0) byId("issue").value = selected;
    updateIssueState();
  }
  function updateIssueState() {
    var custom = currentIssue() === "Other / something else";
    byId("custom-field").hidden = !custom; byId("custom-issue").required = custom;
    byId("emergency-note").hidden = !isEmergencyCategory();
    if (!isEmergencyCategory()) emergencyAcknowledged = false;
  }
  function chooseIssue(categoryKey, label) {
    byId("category").value = categoryKey; populateIssues(label); byId("catalog-search").value = label || ""; byId("search-results").hidden = true; byId("issue").focus();
  }
  function renderSearch() {
    var query = byId("catalog-search").value.trim(), target = byId("search-results");
    if (query.length < 2) { target.hidden = true; target.innerHTML = ""; return; }
    var rows = catalog.search(query).slice(0, 14);
    target.innerHTML = rows.length ? rows.map(function (row) {
      return '<button class="search-result" type="button" data-search-category="' + escapeHtml(row.categoryKey) + '" data-search-label="' + escapeHtml(row.label) + '"><strong>' + escapeHtml(row.label) + '</strong><span>' + escapeHtml(row.categoryLabel) + '</span></button>';
    }).join("") : '<div class="empty" style="padding:14px">No exact match. Choose “Other / something else” and describe it.</div>';
    target.hidden = false;
  }

  function renderRequests(rows) {
    var target = byId("request-history");
    if (!rows || !rows.length) { target.innerHTML = '<div class="empty">No requests sent from this browser yet.</div>'; return; }
    target.innerHTML = rows.map(function (report) {
      var note = report.staff_note || report.resolution_note || (report.status === "reported" ? "Waiting for the host team to acknowledge it." : "The host team is handling this request.");
      return '<article class="guest-request"><div class="preview-top"><strong>' + escapeHtml(report.title) + '</strong><span class="status-pill ' + escapeHtml(report.status) + '">' + escapeHtml(statusLabel(report.status)) + '</span></div><p>' + escapeHtml(report.location) + ' · ' + escapeHtml(formatDate(report.created_at)) + '</p><p>' + escapeHtml(note) + '</p></article>';
    }).join("");
  }
  async function loadRequests() {
    if (!client || !user) return;
    var result = await client.from("guest_reports").select("id,title,location,status,staff_note,resolution_note,created_at,updated_at").eq("guest_user_id", user.id).eq("property_id", property.id).order("created_at", { ascending: false });
    if (result.error) { setConnection("Connected, but status updates could not be refreshed.", "warn"); return; }
    renderRequests(result.data || []);
  }

  function showEmergencyModal() { byId("emergency-modal").hidden = false; }
  function closeEmergencyModal() { byId("emergency-modal").hidden = true; }
  function setPropertyUi() {
    byId("property-name").textContent = property.name;
    byId("host-contact").textContent = property.reception_phone || "Use the urgent contact method in your booking confirmation.";
    var emergency = config.emergencyNumber || "999";
    byId("emergency-link").textContent = "Emergency services: " + emergency;
    byId("emergency-link").href = "tel:" + emergency.replace(/[^0-9+]/g, "");
    byId("modal-emergency-link").textContent = "Call " + emergency;
    byId("modal-emergency-link").href = "tel:" + emergency.replace(/[^0-9+]/g, "");
    document.documentElement.style.setProperty("--brand", property.brand_colour || "#2f8068");
    document.title = property.name + " · InnRelay Stays";
  }

  async function initialiseData() {
    if (!catalog || !window.supabase || !config.supabaseUrl || !config.supabasePublishableKey) { setConnection("This Stay portal is not configured.", "error"); return; }
    try {
      client = window.supabase.createClient(config.supabaseUrl, config.supabasePublishableKey, { auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true, storageKey: "innrelay-stays-guest-auth" } });
      var sessionResult = await client.auth.getSession(); if (sessionResult.error) throw sessionResult.error;
      if (!sessionResult.data.session) {
        var captchaToken = await requestTurnstileToken();
        var signIn = await client.auth.signInAnonymously({ options: { captchaToken: captchaToken } });
        if (signIn.error) throw signIn.error; user = signIn.data.user; byId("verification").hidden = true;
      } else { user = sessionResult.data.session.user; byId("verification").hidden = true; }

      var credentials = portalCredentials();
      if (!credentials.propertyId || !credentials.locationId || !credentials.propertyToken || !credentials.locationToken) throw new Error("This page needs a current InnRelay Stays QR card.");
      propertyToken = credentials.propertyToken; scannedLocationId = credentials.locationId;
      var portalResult = await client.from("guest_portal_sessions").upsert({
        user_id: user.id, property_id: credentials.propertyId, location_id: credentials.locationId,
        property_token: credentials.propertyToken, location_token: credentials.locationToken,
        expires_at: new Date(Date.now() + 8 * 86400000).toISOString(), last_seen_at: new Date().toISOString()
      }, { onConflict: "user_id,property_id,location_id" });
      if (portalResult.error) throw portalResult.error;

      var propertyResult = await client.from("properties").select("id,public_id,name,slug,reception_phone,emergency_notice,brand_colour,property_type,active").eq("id", credentials.propertyId).eq("active", true).single();
      if (propertyResult.error) throw propertyResult.error;
      if (propertyResult.data.property_type !== "short_term_rental") { window.location.replace(hotelGuestUrl()); return; }
      property = propertyResult.data; setPropertyUi();

      var locationsResult = await client.from("property_locations").select("id,property_id,public_id,name,code,location_type,active,sort_order").eq("property_id", property.id).eq("active", true).order("sort_order").order("name");
      if (locationsResult.error) throw locationsResult.error;
      locations = (locationsResult.data || []).filter(function (location) { return location.location_type !== "room" && ["reception", "bar", "restaurant", "gym"].indexOf(location.location_type) < 0; });
      var scanned = locations.filter(function (location) { return location.id === scannedLocationId; })[0];
      if (!scanned) throw new Error("The scanned area is not active for this Stay.");
      await selectLocation(scanned, false);
      renderPopular(); populateCategories(); await loadRequests();
      setConnection("Secure live connection · the host team will receive requests for " + property.name, "live");
      channel = client.channel("stays-guest-" + user.id).on("postgres_changes", { event: "*", schema: "public", table: "guest_reports", filter: "guest_user_id=eq." + user.id }, loadRequests).subscribe();
    } catch (error) {
      setConnection(friendlyError(error, "This InnRelay Stays QR could not be opened. Scan the printed card again or contact the host team."), "error");
      byId("submit-report").disabled = true;
    }
  }

  var ALLOWED_ATTACHMENT_TYPES = ["image/jpeg", "image/png", "image/webp", "image/heic", "application/pdf"];
  var MAX_ATTACHMENT_BYTES = 8 * 1024 * 1024;

  function validateAttachment(file) {
    if (!file) return null;
    if (ALLOWED_ATTACHMENT_TYPES.indexOf(file.type) === -1) return "That file type isn't supported. Attach a JPEG, PNG, WEBP, HEIC photo or a PDF.";
    if (file.size > MAX_ATTACHMENT_BYTES) return "That file is too large. Attachments must be 8MB or smaller.";
    return null;
  }

  async function uploadStaysAttachment(reportId, file) {
    var safeName = file.name.replace(/[^a-zA-Z0-9.\-_]/g, "_").slice(-80) || "attachment";
    var path = reportId + "/" + Date.now() + "-" + safeName;
    var uploadResult = await client.storage.from("guest-report-attachments").upload(path, file, { contentType: file.type, upsert: false });
    if (uploadResult.error) throw uploadResult.error;
    var insertResult = await client.from("guest_report_attachments").insert({
      report_id: reportId, property_id: property.id, storage_path: path,
      mime_type: file.type, size_bytes: file.size,
      uploaded_by_kind: "guest", uploaded_by_user_id: user.id
    });
    if (insertResult.error) throw insertResult.error;
  }

  async function submitReport(event) {
    event.preventDefault();
    if (!client || !user || !property || !selectedLocation) { setConnection("Scan a current InnRelay Stays QR card before sending a request.", "error"); return; }
    var category = currentCategory();
    var selected = currentIssue();
    var title = selected === "Other / something else" ? byId("custom-issue").value.trim() : selected;
    if (!category || !title) { setConnection("Choose a Stay category and describe the request.", "error"); return; }
    if (category.emergency && !emergencyAcknowledged) { showEmergencyModal(); return; }
    var attachmentInput = byId("attachment");
    var attachmentFile = attachmentInput && attachmentInput.files && attachmentInput.files[0];
    var attachmentError = validateAttachment(attachmentFile);
    if (attachmentError) { setConnection(attachmentError, "error"); return; }
    var button = byId("submit-report"); button.disabled = true; button.textContent = "Sending securely…";
    var payload = {
      property_id: property.id, location_id: selectedLocation.id,
      category_key: category.key, category_label: category.label,
      issue_code: category.key + ":" + catalog.slugify(title), title: title,
      description: byId("description").value.trim(), urgency: byId("urgency").value,
      guest_impact: byId("urgency").value === "urgent" ? "guest_waiting" : "guest_affected",
      guest_name: byId("guest-name").value.trim() || null, contact_preference: "app",
      idempotency_key: idempotencyKey,
      client_context: { vertical: "short_term_rental", language: navigator.language || "", timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || "", path: window.location.pathname }
    };
    var attachmentWarning = "";
    try {
      var result = await client.rpc("submit_stays_guest_report", { p_payload: payload });
      if (result.error) throw result.error;
      var created = Array.isArray(result.data) ? result.data[0] : result.data;
      if (created && created.id && attachmentFile) {
        try { await uploadStaysAttachment(created.id, attachmentFile); }
        catch (attachError) {
          console.error("InnRelay Stays attachment upload failed", attachError);
          attachmentWarning = " Your photo could not be attached, but the request itself was sent.";
        }
      }
      byId("report-panel").hidden = true; byId("success-panel").hidden = false;
      byId("success-copy").textContent = "“" + title + "” was sent for " + selectedLocation.name + ". Follow the status on this page." + attachmentWarning;
      idempotencyKey = newIdempotencyKey(); await loadRequests();
      setConnection("Request sent securely to the host team.", "live");
      if (created && created.id) client.functions.invoke("notify-guest-report", { body: { report_id: created.id, event: "created" } }).catch(function () {});
    } catch (error) { setConnection(friendlyError(error), "error"); }
    finally { button.disabled = false; button.textContent = "Send to host team"; }
  }

  function resetForm() {
    byId("report-form").reset(); byId("report-panel").hidden = false; byId("success-panel").hidden = true;
    emergencyAcknowledged = false; idempotencyKey = newIdempotencyKey(); populateCategories(); byId("catalog-search").value = ""; byId("search-results").hidden = true;
  }

  byId("report-form").addEventListener("submit", submitReport);
  byId("category").addEventListener("change", function () { populateIssues(); if (isEmergencyCategory()) showEmergencyModal(); });
  byId("issue").addEventListener("change", function () { updateIssueState(); if (isEmergencyCategory()) showEmergencyModal(); });
  byId("catalog-search").addEventListener("input", renderSearch);
  byId("search-results").addEventListener("click", function (event) { var button = event.target.closest("[data-search-category]"); if (button) chooseIssue(button.getAttribute("data-search-category"), button.getAttribute("data-search-label")); });
  byId("popular-categories").addEventListener("click", function (event) { var button = event.target.closest("[data-category-key]"); if (button) { byId("category").value = button.getAttribute("data-category-key"); populateIssues(); byId("category").focus(); } });
  byId("area-chips").addEventListener("click", function (event) { var button = event.target.closest("[data-location-id]"); if (!button) return; var location = locations.filter(function (item) { return item.id === button.getAttribute("data-location-id"); })[0]; if (location) selectLocation(location, true); });
  byId("report-another").addEventListener("click", resetForm);
  byId("emergency-confirm").addEventListener("click", function () { emergencyAcknowledged = true; closeEmergencyModal(); byId("description").focus(); });
  byId("turnstile-retry").addEventListener("click", function () { window.location.reload(); });

  if ("serviceWorker" in navigator && window.location.protocol !== "file:") {
    navigator.serviceWorker.register("./innrelay-service-worker.js").catch(function () {});
  }

  initialiseData();
}());
