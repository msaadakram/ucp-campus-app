'use strict';

/* Tiny validation helpers shared by routes: reject garbage at the edge
 * with 400s so Supabase never sees it. */

const FLAIRS = ['Study', 'Events', 'Help', 'Memes', 'Marketplace'];

function isUuid(v) {
  return (
    typeof v === 'string' &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v)
  );
}

function cleanText(v, max) {
  if (typeof v !== 'string') return null;
  const t = v.trim().replace(/\s+/g, ' ');
  if (!t || t.length > max) return null;
  return t;
}

function cleanTitle(v) {
  return cleanText(v, 120);
}

function cleanBody(v) {
  if (v === undefined || v === null || v === '') return '';
  return cleanText(String(v), 2000);
}

function cleanComment(v) {
  return cleanText(v, 2000);
}

function cleanVote(v) {
  if (v === null || v === undefined) return null;
  const n = Number(v);
  return n === 1 || n === -1 ? n : 'invalid';
}

module.exports = { FLAIRS, isUuid, cleanText, cleanTitle, cleanBody, cleanComment, cleanVote };
