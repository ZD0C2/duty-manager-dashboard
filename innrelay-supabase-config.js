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
    // Set this only after the guest file is publicly deployed and tested.
    // Managers can also enter the live URL directly in the QR generator.
    publicGuestUrl: "",
    receptionPhone: "Use the room phone and select Reception",
    emergencyNumber: "999",
    demoMode: false,
    catalogueVersion: "2026.07.13"
  };
}(window));
