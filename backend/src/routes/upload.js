'use strict';

/* Photo uploads: multipart image -> Supabase Storage (public bucket) ->
 * public URL the app attaches to a post. Auth required; 5 MB cap; images
 * only (magic bytes are NOT sniffed — extension + mime gate, same as the
 * app-side picker; tighten with sharp/file-type if abuse appears). */

const express = require('express');
const multer = require('multer');
const { getSupabase } = require('../supabase');

const BUCKET = 'community-images';
const MAX_BYTES = 5 * 1024 * 1024;
const ALLOWED = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
]);

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_BYTES, files: 1 },
  fileFilter: (_req, file, cb) => {
    if (ALLOWED.has(file.mimetype)) return cb(null, true);
    cb(new Error('only jpeg, png, webp or gif images allowed'));
  },
});

function extFor(mimetype) {
  return (
    { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp', 'image/gif': 'gif' }[
      mimetype
    ] || 'jpg'
  );
}

function routes({ config, requireUser }) {
  const router = express.Router();
  const db = () => getSupabase(config);

  router.post('/upload', requireUser, (req, res) => {
    upload.single('image')(req, res, async (err) => {
      if (err) {
        const tooBig = /file size|File too large/i.test(err.message || '');
        return res.status(400).json({
          error: tooBig
            ? 'image must be under 5 MB'
            : err.message || 'upload rejected',
        });
      }
      if (!req.file) {
        return res.status(400).json({ error: 'field "image" is required' });
      }
      try {
        const path =
          `posts/${Date.now()}_${Math.round(Math.random() * 1e9)}.` +
          `${extFor(req.file.mimetype)}`;
        const { error } = await db()
          .storage.from(BUCKET)
          .upload(path, req.file.buffer, {
            contentType: req.file.mimetype,
            upsert: false,
          });
        if (error) throw error;
        const { data } = db().storage.from(BUCKET).getPublicUrl(path);
        res.status(201).json({ url: data.publicUrl, path });
      } catch (_) {
        res.status(502).json({ error: 'upload failed, try again' });
      }
    });
  });

  return router;
}

module.exports = { routes, BUCKET, MAX_BYTES, ALLOWED };
