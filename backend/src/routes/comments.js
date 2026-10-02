'use strict';

/* Comment threads + comment votes. Same rule as posts: identity comes from
 * the verified Odoo session, never from request bodies. */

const express = require('express');
const { getSupabase } = require('../supabase');
const events = require('../events');
const { isUuid, cleanComment, cleanVote } = require('../middleware/validate');

function shapeComment(row, score, mine) {
  return {
    id: String(row.id),
    postId: String(row.post_id),
    parentId: row.parent_id ? String(row.parent_id) : null,
    author: row.author_name || 'student',
    text: row.text || '',
    time: row.created_at,
    score,
    vote: mine,
  };
}

function routes({ config, requireUser }) {
  const router = express.Router();
  const db = () => getSupabase(config);

  /* Full thread for a post, oldest first (client nests via parentId). */
  router.get('/posts/:id/comments', async (req, res) => {
    const { id } = req.params;
    if (!isUuid(id)) return res.status(400).json({ error: 'bad post id' });
    try {
      const me = req.user ? req.user.email : '';
      const { data: rows, error } = await db()
        .from('community_comments')
        .select('*')
        .eq('post_id', id)
        .order('created_at', { ascending: true });
      if (error) throw error;
      const ids = rows.map((r) => r.id);
      let votes = [];
      if (ids.length) {
        const v = await db()
          .from('community_comment_votes')
          .select('comment_id, author_email, value')
          .in('comment_id', ids);
        if (v.error) throw v.error;
        votes = v.data;
      }
      const byComment = {};
      for (const v of votes) {
        (byComment[v.comment_id] = byComment[v.comment_id] || {
          score: 0,
          mine: 0,
        });
        const n = Number(v.value) || 0;
        byComment[v.comment_id].score += n;
        if (v.author_email === me) byComment[v.comment_id].mine = n;
      }
      res.json({
        comments: rows.map((r) => {
          const agg = byComment[r.id] || { score: 0, mine: 0 };
          return shapeComment(r, agg.score - agg.mine, agg.mine);
        }),
      });
    } catch (err) {
      res.status(502).json({ error: 'thread unavailable, try again' });
    }
  });

  /* Reply (parentId) or top-level comment (auth required). */
  router.post('/posts/:id/comments', requireUser, async (req, res) => {
    const { id } = req.params;
    if (!isUuid(id)) return res.status(400).json({ error: 'bad post id' });
    const text = cleanComment(req.body && req.body.text);
    if (text === null) {
      return res.status(400).json({ error: 'text 1..2000 chars required' });
    }
    const parentId = req.body && req.body.parentId;
    if (parentId !== undefined && parentId !== null && !isUuid(parentId)) {
      return res.status(400).json({ error: 'bad parent id' });
    }
    try {
      // Parent must belong to the same post (no cross-thread grafting).
      if (parentId) {
        const { data: parent, error: pErr } = await db()
          .from('community_comments')
          .select('id, post_id')
          .eq('id', parentId)
          .maybeSingle();
        if (pErr) throw pErr;
        if (!parent || parent.post_id !== id) {
          return res
            .status(400)
            .json({ error: 'parent comment is not on this post' });
        }
      }
      const { data, error } = await db()
        .from('community_comments')
        .insert({
          post_id: id,
          parent_id: parentId || null,
          author_email: req.user.email,
          author_name: req.user.name,
          text,
        })
        .select()
        .single();
      if (error) throw error;
      events.broadcast();
      res.status(201).json({ comment: shapeComment(data, 0, 0) });
    } catch (err) {
      res.status(502).json({ error: 'could not comment, try again' });
    }
  });

  /* Toggle my vote on a comment. */
  router.post('/comments/:id/vote', requireUser, async (req, res) => {
    const { id } = req.params;
    if (!isUuid(id)) return res.status(400).json({ error: 'bad comment id' });
    const value = cleanVote(req.body && req.body.value);
    if (value === 'invalid') {
      return res.status(400).json({ error: 'value must be 1, -1 or omitted' });
    }
    try {
      if (value === null) {
        const { error } = await db()
          .from('community_comment_votes')
          .delete()
          .eq('comment_id', id)
          .eq('author_email', req.user.email);
        if (error) throw error;
      } else {
        const { error } = await db()
          .from('community_comment_votes')
          .upsert(
            { comment_id: id, author_email: req.user.email, value },
            { onConflict: 'comment_id,author_email' },
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

module.exports = { routes, shapeComment };
