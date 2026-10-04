'use strict';

/* Teacher reviews API (StudentSpace parsed data + live student ratings).
 * Author identity ALWAYS comes from the verified Odoo session (req.user).
 * Ratings are 1..5 on three dimensions; overall = mean of the three.
 */

const express = require('express');
const { getSupabase } = require('../supabase');

function clampRating(v) {
  const n = Number(v);
  if (!Number.isFinite(n)) return null;
  const r = Math.round(n);
  return r >= 1 && r <= 5 ? r : null;
}

function cleanSlug(v) {
  if (typeof v !== 'string') return null;
  const s = v.trim().toLowerCase();
  if (!/^[a-z0-9-]{3,80}$/.test(s)) return null;
  return s;
}

function cleanComment(v) {
  if (v === undefined || v === null || v === '') return '';
  if (typeof v !== 'string') return null;
  const t = v.trim().replace(/\s+/g, ' ');
  if (t.length > 2000) return null;
  return t;
}

function shapeTeacher(row) {
  return {
    slug: row.slug,
    name: row.name || '',
    designation: row.designation || '',
    department_code: row.department_code || '',
    department_name: row.department_name || '',
    department_id: Number(row.department_id) || 0,
    image_url: row.image_url || '',
    bio: row.bio || '',
    overall_rating: Number(row.overall_rating) || 0,
    review_count: Number(row.review_count) || 0,
    grading_pct: Number(row.grading_pct) || 0,
    leniency_pct: Number(row.leniency_pct) || 0,
    subject_pct: Number(row.subject_pct) || 0,
    avg_grading: Number(row.avg_grading) || 0,
    avg_leniency: Number(row.avg_leniency) || 0,
    avg_subject: Number(row.avg_subject) || 0,
    profile_url: row.profile_url || '',
    updated_at: row.updated_at || null,
  };
}

function shapeReview(row) {
  return {
    id: row.id,
    teacher_slug: row.teacher_slug,
    student_name: row.student_name || 'student',
    comment: row.comment || '',
    rating_grading: Number(row.rating_grading) || 0,
    rating_leniency: Number(row.rating_leniency) || 0,
    rating_subject: Number(row.rating_subject) || 0,
    is_blocked: !!row.is_blocked,
    created_at: row.created_at || null,
  };
}

async function recomputeTeacher(db, slug) {
  const { data, error } = await db()
    .from('teacher_reviews')
    .select('rating_grading, rating_leniency, rating_subject')
    .eq('teacher_slug', slug)
    .eq('is_blocked', false);
  if (error) throw error;
  const n = data.length;
  let overall = 0;
  let ag = 0;
  let al = 0;
  let as = 0;
  if (n > 0) {
    ag = data.reduce((a, r) => a + Number(r.rating_grading), 0) / n;
    al = data.reduce((a, r) => a + Number(r.rating_leniency), 0) / n;
    as = data.reduce((a, r) => a + Number(r.rating_subject), 0) / n;
    overall = (ag + al + as) / 3;
  }
  const pct = (v) => Math.round((v / 5) * 100);
  const { error: upErr } = await db()
    .from('teachers')
    .update({
      overall_rating: Math.round(overall * 10) / 10,
      review_count: n,
      grading_pct: n ? pct(ag) : 0,
      leniency_pct: n ? pct(al) : 0,
      subject_pct: n ? pct(as) : 0,
      avg_grading: Math.round(ag * 100) / 100,
      avg_leniency: Math.round(al * 100) / 100,
      avg_subject: Math.round(as * 100) / 100,
      updated_at: new Date().toISOString(),
    })
    .eq('slug', slug);
  if (upErr) throw upErr;
  return { overall, n, ag, al, as };
}

function routes({ config, requireUser }) {
  const router = express.Router();
  const db = () => getSupabase(config);

  /* GET /teachers?dept=foit&q=usman&limit=1000 — highest rated first. */
  router.get('/teachers', async (req, res) => {
    try {
      const limit = Math.min(
        Math.max(parseInt(req.query.limit || '1000', 10) || 1000, 1),
        1000,
      );
      const dept =
        typeof req.query.dept === 'string' ? req.query.dept.trim() : '';
      const q = typeof req.query.q === 'string' ? req.query.q.trim() : '';
      let query = db()
        .from('teachers')
        .select('*')
        .order('overall_rating', { ascending: false })
        .order('review_count', { ascending: false })
        .limit(limit);
      if (dept) query = query.eq('department_code', dept);
      if (q) query = query.ilike('name', `%${q}%`);
      const { data, error } = await query;
      if (error) throw error;
      res.json({ teachers: data.map(shapeTeacher) });
    } catch (err) {
      res.status(502).json({ error: 'teachers unavailable, try again' });
    }
  });

  /* GET /teachers/:slug — teacher + latest reviews. */
  router.get('/teachers/:slug', async (req, res) => {
    try {
      const slug = cleanSlug(req.params.slug);
      if (!slug) return res.status(400).json({ error: 'bad teacher slug' });
      const { data: t, error: tErr } = await db()
        .from('teachers')
        .select('*')
        .eq('slug', slug)
        .single();
      if (tErr || !t) return res.status(404).json({ error: 'teacher not found' });
      const { data: revs, error: rErr } = await db()
        .from('teacher_reviews')
        .select('*')
        .eq('teacher_slug', slug)
        .order('created_at', { ascending: false })
        .limit(200);
      if (rErr) throw rErr;
      res.json({ teacher: shapeTeacher(t), reviews: revs.map(shapeReview) });
    } catch (err) {
      res.status(502).json({ error: 'teacher unavailable, try again' });
    }
  });

  /* POST /teachers/:slug/rate {grading, leniency, subject, comment} — auth. */
  router.post('/teachers/:slug/rate', requireUser, async (req, res) => {
    try {
      const slug = cleanSlug(req.params.slug);
      if (!slug) return res.status(400).json({ error: 'bad teacher slug' });
      const grading = clampRating(req.body && req.body.grading);
      const leniency = clampRating(req.body && req.body.leniency);
      const subject = clampRating(req.body && req.body.subject);
      const comment = cleanComment(req.body && req.body.comment);
      if (grading === null || leniency === null || subject === null) {
        return res
          .status(400)
          .json({ error: 'grading, leniency, subject must each be 1..5' });
      }
      if (comment === null) {
        return res
          .status(400)
          .json({ error: 'comment must be 2000 chars or less' });
      }
      const { data: exists, error: exErr } = await db()
        .from('teachers')
        .select('slug')
        .eq('slug', slug)
        .single();
      if (exErr || !exists) {
        return res.status(404).json({ error: 'teacher not found' });
      }
      const { data, error } = await db()
        .from('teacher_reviews')
        .insert({
          teacher_slug: slug,
          student_name: req.user.name || 'student',
          author_email: req.user.email,
          comment: comment || '',
          rating_grading: grading,
          rating_leniency: leniency,
          rating_subject: subject,
          is_blocked: false,
        })
        .select()
        .single();
      if (error) throw error;
      const stats = await recomputeTeacher(db, slug);
      res.status(201).json({ review: shapeReview(data), stats });
    } catch (err) {
      res.status(502).json({ error: 'could not save rating, try again' });
    }
  });

  return router;
}

module.exports = { routes, shapeTeacher, shapeReview, clampRating, cleanSlug, cleanComment };
