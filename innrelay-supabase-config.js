(function (global) {
  "use strict";

  /*
   * Public browser configuration only.
   * A Supabase publishable key is intentionally safe to expose when every
   * exposed table is protected by Row Level Security. Never place a secret or
   * service_role key in this file.
   */
  global.INNRELAY_CONFIG = {
    supabaseUrl: "https://bkwzfoleuwhnuhqzxyqo.supabase.co",
    supabasePublishableKey: "sb_publishable_hWv_41IDXZ4LsWaHLFHKXA_NkDI8QTf",
    propertySlug: "exhibition-court",
    propertyName: "Exhibition Court Hotel",
    publicStaffUrl: "https://zd0c2.github.io/duty-manager-dashboard/innrelay-prototype.html",
    publicGuestUrl: "https://zd0c2.github.io/duty-manager-dashboard/innrelay-guest.html",
    publicStaysUrl: "https://zd0c2.github.io/duty-manager-dashboard/innrelay-stays.html",
    publicStaysGuestUrl: "https://zd0c2.github.io/duty-manager-dashboard/innrelay-stays-guest.html",
    productChooserUrl: "https://zd0c2.github.io/duty-manager-dashboard/innrelay-start.html",
    // Public Cloudflare Turnstile site key. The private secret stays in Supabase Auth settings.
    turnstileSiteKey: "0x4AAAAAAD3vbYOgg4XyOhrS",
    // Browser-restricted Google Maps key for the hotel directory menu.
    // Keep the manual registration fallback enabled even with this set.
    // Restricted by HTTP referrer in Google Cloud Console to zd0c2.github.io
    // and innrelay.com, and to only the Maps JavaScript API + Places API.
    googlePlacesApiKey: "AIzaSyDNz0Ctpgyz3d2m9NRibyHCQnhfJrYjy_k",
    hotelSearchCountry: "gb",
    receptionPhone: "Use the room phone and select Reception",
    emergencyNumber: "999",
    demoMode: false,
    catalogueVersion: "2026.07.13"
  };
}(window));
