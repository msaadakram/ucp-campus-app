'use strict';

/* Real campus numbers for the `r/campus` header.
 * - members: distinct UCP emails that ever contributed (post / comment /
 *   vote). 100% derived from data, never hardcoded.
 * - online: current SSE subscribers on GET /api/stream (live feed viewers).
 * Public endpoint (same as the feed itself); never throws — degrades to
 * zeros so the feed still loads when stats fail. */

const { getSupabase } = require('../supabase');
const events = require('../events');

function distinctEmails(rows) {
  const set = new Set();
  for (const r of rows || []) {
    const e = (r && r.author_email ? String(r.author_email) : '').trim().toLowerCase();
    if (e) set.add(e);
  }
  return set;
}

async function collectMembers(db) {
  const tables = [
    'community_posts',
    'community_comments',
    'community_votes',
    'community_comment_votes',
  ];
  const all = new Set();
  for (const t of tables) {
    try {
      const { data, error } = await db().from(t).select('author_email').limit(1000);
      if (error || !data) continue;
      for (const e of distinctEmails(data)) all.add(e);
    } catch (_) {
      // One table failing must not kill the whole stat.
    }
  }
  return all.size;
}

function routes({ config }) {
  const express = require('express');
  const router = express.Router();
  const db = () => getSupabase(config);

  router.get('/stats', async (_req, res) => {
    try {
      const members = await collectMembers(db);
      res.json({ members, online: events.clientCount() });
    } catch (_) {
      res.json({ members: 0, online: events.clientCount() });
    }
  });

  return router;
}

module.exports = { routes, distinctEmails, collectMembers };
