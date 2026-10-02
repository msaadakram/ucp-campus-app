'use strict';

/* Request authentication: resolves the caller from their Odoo portal
 * session and attaches it as req.user ({uid, email, name}). Reads and the
 * SSE stream may pass without a session (they carry only public data);
 * every write route uses requireUser. */

const { verifyOdooSession } = require('../odoo');

function sessionFromReq(req) {
  return (
    req.get('x-ucp-session') ||
    req.query.session_id ||
    ''
  ).trim();
}

/* Factory so tests can inject a fake verifier. */
function makeAuth({ odooBase, verify = verifyOdooSession }) {
  async function attachUser(req, _res, next) {
    try {
      const sid = sessionFromReq(req);
      req.user = sid ? await verify(odooBase, sid) : null;
    } catch (_) {
      req.user = null;
    }
    next();
  }

  function requireUser(req, res, next) {
    if (!req.user) {
      return res.status(401).json({
        error: 'portal session expired or missing — sign in again in the app',
      });
    }
    return next();
  }

  return { attachUser, requireUser, sessionFromReq };
}

module.exports = { makeAuth };
