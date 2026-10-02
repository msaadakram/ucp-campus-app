'use strict';

/* Odoo (Horizon portal) session verification: the single source of truth
 * for "who is calling". The app sends the portal `session_id` it captured
 * at Microsoft login; we ask Odoo itself whether it is live and who owns
 * it. No Odoo session, no writes — author identity always comes from the
 * server answer, never from client-supplied strings. */

async function verifyOdooSession(odooBase, sessionId, fetchImpl = fetch) {
  if (!sessionId) return null;
  let res;
  try {
    res = await fetchImpl(`${odooBase}/web/session/get_session_info`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Cookie: `session_id=${sessionId}`,
      },
      body: JSON.stringify({ jsonrpc: '2.0', method: 'call', params: {} }),
    });
  } catch (_) {
    return null; // portal unreachable: fail closed
  }
  if (!res.ok) return null;
  let decoded;
  try {
    decoded = await res.json();
  } catch (_) {
    return null;
  }
  const result = decoded && decoded.result;
  if (!result || typeof result.uid !== 'number') return null;
  const email =
    result.username || result.login || result.email || `user-${result.uid}`;
  return {
    uid: result.uid,
    email: String(email),
    name: String(result.name || email),
  };
}

module.exports = { verifyOdooSession };
