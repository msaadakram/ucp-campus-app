'use strict';

/* Supabase admin client (service_role): RLS is bypassed here ON PURPOSE —
 * authorization happens in our own middleware (verified Odoo portal
 * session), so the database policies stay simple and the app never sees
 * a privileged key. */

const { createClient } = require('@supabase/supabase-js');

let client = null;

function getSupabase(config) {
  if (client) return client;
  client = createClient(config.supabaseUrl, config.supabaseServiceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  return client;
}

/* Test seam: swap the client for mocks. */
function __setClient(mock) {
  client = mock;
}

function __resetClient() {
  client = null;
}

module.exports = { getSupabase, __setClient, __resetClient };
