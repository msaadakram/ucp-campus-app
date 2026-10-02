'use strict';

/* Community read + write API. Author identity ALWAYS comes from the
 * verified Odoo session (req.user) — client-supplied author strings are
 * ignored, so nobody can post or vote as someone else. */

const express = require('express');
const { getSupabase } = require('../supabase');
const events = require('../events');
const {
  FLAIRS,
  isUuid,
  cleanTitle,
  cleanBody,
  cleanVote,
} = require('../middleware/validate');

function ageMinutes(iso, nowMs) {
  const t = Date.parse(iso);
  if (Number.isNaN(t)) return 0;
  return Math.max(0, Math.round((nowMs - t) / 60000));
}

function timeLabel(ageMin) {
  if (ageMin < 1) return 'now';
  if (ageMin < 60) return `${ageMin}m`;
  const h = Math.floor(ageMin / 60);
  if (h < 24) return `${h}h`;
  return `${Math.floor(h / 24)}d`;
}

/* Shape rows exactly like the Flutter UI models expect. */
function shapePost(row, votes, myEmail, nowMs) {
  let score = 0;
  let mine = 0;
  for (const v of votes) {
    const n = Number(v.value) || 0;
    score += n;
    if (v.author_email === myEmail) mine = n;
  }
  return {
    id: String(row.id),
    author: row.author_name || 'student',
    flair: row.flair || 'Study',
    title: row.title || '',
    body: row.body || '',
    time: timeLabel(ageMinutes(row.created_at, nowMs)),
    ageMinutes: ageMinutes(row.created_at, nowMs),
    score: score - mine, // UI renders score + vote
    vote: mine,
    imageUrl: row.image_url || null,
  };
}

function routes({ config, requireUser }) {
  const router = express.Router();
  const db = () => getSupabase(config);

  /* Public feed: newest first with scores + my votes + full comment
   * threads (embedded flat; the app nests via parentId). Reads are open
   * (campus feed); pass ?session_id= or the header to also get MY votes. */
  router.get('/posts', async (req, res) => {
    try {
      const limit = Math.min(
        Math.max(parseInt(req.query.limit || '40', 10) || 40, 1),
        100,
      );
      const me = req.user ? req.user.email : '';
      const nowMs = Date.now();
      const { data: rows, error } = await db()
        .from('community_posts')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(limit);
      if (error) throw error;
      const ids = rows.map((r) => r.id);
      let votes = [];
      let commentRows = [];
      let commentVotes = [];
      if (ids.length) {
        const v = await db()
          .from('community_votes')
          .select('post_id, author_email, value')
          .in('post_id', ids);
        if (v.error) throw v.error;
        votes = v.data;
        const c = await db()
          .from('community_comments')
          .select('*')
          .in('post_id', ids)
          .order('created_at', { ascending: true });
        if (c.error) throw c.error;
        commentRows = c.data;
        const cids = commentRows.map((r) => r.id);
        if (cids.length) {
          const cv = await db()
            .from('community_comment_votes')
            .select('comment_id, author_email, value')
            .in('comment_id', cids);
          if (cv.error) throw cv.error;
          commentVotes = cv.data;
        }
      }
      const byPost = {};
      for (const v of votes) {
        (byPost[v.post_id] = byPost[v.post_id] || { score: 0, mine: 0 });
        const n = Number(v.value) || 0;
        byPost[v.post_id].score += n;
        if (v.author_email === me) byPost[v.post_id].mine = n;
      }
      const commentsByPost = {};
      for (const c of commentRows) {
        (commentsByPost[c.post_id] = commentsByPost[c.post_id] || []).push(c);
      }
      const commentScore = {};
      for (const v of commentVotes) {
        (commentScore[v.comment_id] = commentScore[v.comment_id] || {
          score: 0,
          mine: 0,
        });
        const n = Number(v.value) || 0;
        commentScore[v.comment_id].score += n;
        if (v.author_email === me) commentScore[v.comment_id].mine = n;
      }
      res.json({
        posts: rows.map((r) => {
          const agg = byPost[r.id] || { score: 0, mine: 0 };
          const shaped = shapePost(r, [], '', nowMs);
          return {
            ...shaped,
            commentCount: (commentsByPost[r.id] || []).length,
            score: agg.score - agg.mine,
            vote: agg.mine,
            comments: (commentsByPost[r.id] || []).map((c) => {
              const a = commentScore[c.id] || { score: 0, mine: 0 };
              return {
                id: String(c.id),
                parent_id: c.parent_id ? String(c.parent_id) : null,
                author_name: c.author_name || 'student',
                text: c.text || '',
                created_at: c.created_at,
                score: a.score - a.mine,
                vote: a.mine,
              };
            }),
          };
        }),
      });
    } catch (err) {
      res.status(502).json({ error: 'feed unavailable, try again' });
    }
  });

  /* Publish a post (auth required). */
  router.post('/posts', requireUser, async (req, res) => {
    const title = cleanTitle(req.body && req.body.title);
    const body = cleanBody(req.body && req.body.body);
    const flair = req.body && req.body.flair;
    const imageUrl =
      req.body && typeof req.body.imageUrl === 'string'
        ? req.body.imageUrl.slice(0, 500)
        : null;
    if (title === null) {
      return res.status(400).json({ error: 'title 1..120 chars required' });
    }
    if (body === null) {
      return res.status(400).json({ error: 'body max 2000 chars' });
    }
    if (!FLAIRS.includes(flair)) {
      return res
        .status(400)
        .json({ error: `flair must be one of ${FLAIRS.join(', ')}` });
    }
    try {
      const { data, error } = await db()
        .from('community_posts')
        .insert({
          author_email: req.user.email,
          author_name: req.user.name,
          title,
          body,
          flair,
          image_url: imageUrl,
        })
        .select()
        .single();
      if (error) throw error;
      events.broadcast();
      res.status(201).json({
        post: shapePost(data, [], req.user.email, Date.now()),
      });
    } catch (err) {
      res.status(502).json({ error: 'could not publish, try again' });
    }
  });

  /* Toggle my vote: {value: 1|-1} sets, {} or null clears. */
  router.post('/posts/:id/vote', requireUser, async (req, res) => {
    const { id } = req.params;
    if (!isUuid(id)) return res.status(400).json({ error: 'bad post id' });
    const value = cleanVote(req.body && req.body.value);
    if (value === 'invalid') {
      return res.status(400).json({ error: 'value must be 1, -1 or omitted' });
    }
    try {
      if (value === null) {
        const { error } = await db()
          .from('community_votes')
          .delete()
          .eq('post_id', id)
          .eq('author_email', req.user.email);
        if (error) throw error;
      } else {
        const { error } = await db().from('community_votes').upsert(
          { post_id: id, author_email: req.user.email, value },
          { onConflict: 'post_id,author_email' },
        );
        if (error) throw error;
      }
      events.broadcast();
      res.json({ ok: true, value });
    } catch (err) {
      res.status(502).json({ error: 'could not save vote, try again' });
    }
  });

  return router;
}

module.exports = { routes, shapePost, timeLabel, ageMinutes };
