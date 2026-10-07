'use strict';

/* App factory: every collaborator injectable so supertest + jest cover the
 * HTTP layer with zero network (fake Supabase, fake Odoo verifier). */

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');

const { makeAuth } = require('./middleware/auth');
const events = require('./events');
const postsRoutes = require('./routes/posts');
const teachersRoutes = require('./routes/teachers');
const commentsRoutes = require('./routes/comments');
const uploadRoutes = require('./routes/upload');
const statsRoutes = require('./routes/stats');

function createApp({
  config,
  verify,
  now = () => Date.now(),
  enableRateLimit = true,
} = {}) {
  if (!config) {
    throw new Error('createApp requires { config }');
  }
  const app = express();
  app.disable('x-powered-by');
  app.use(helmet({ crossOriginResourcePolicy: false }));
  app.use(
    cors({
      origin:
        !config.corsOrigin || config.corsOrigin === '*'
          ? '*'
          : config.corsOrigin.split(',').map((s) => s.trim()),
    }),
  );
  app.use(express.json({ limit: '256kb' }));
  if (process.env.NODE_ENV !== 'test') app.use(morgan('tiny'));

  if (enableRateLimit) {
    app.use(
      '/api/',
      rateLimit({ windowMs: 15 * 60 * 1000, max: 300, standardHeaders: true }),
    );
    app.use(
      '/api/upload',
      rateLimit({ windowMs: 15 * 60 * 1000, max: 30, standardHeaders: true }),
    );
  }

  const { attachUser, requireUser } = makeAuth({
    odooBase: config.odooBase,
    verify,
  });
  app.use('/api/', attachUser);

  /* Browser landing page: opening the API URL in a browser shows this
   * instead of a 404. It is an API server, not a website. */
  app.get('/', (_req, res) => {
    res.type('html').send(`<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>UCP Campus API</title>
<style>body{font-family:system-ui,sans-serif;max-width:640px;margin:48px auto;padding:0 20px;color:#0A3F47}
h1{font-size:28px}a{color:#0C6F7D}code{background:#F1F5F6;padding:2px 6px;border-radius:6px}
ul{line-height:2}</style></head><body>
<h1>UCP Campus API</h1>
<p>This server powers the UCP Campus Flutter app (community + teacher reviews).
It has no website here &mdash; use the endpoints below.</p>
<ul>
<li><a href="/api/health"><code>GET /api/health</code></a> &mdash; server status</li>
<li><code>GET /api</code> &mdash; full endpoint list (JSON)</li>
<li><code>GET /api/posts</code> &mdash; community feed</li>
<li><code>GET /api/teachers</code> &mdash; teacher reviews</li>
<li><code>GET /api/stats</code> &mdash; live counters</li>
</ul>
<p>Writes require header <code>x-ucp-session</code> (verified against Odoo).</p>
</body></html>`);
  });

  /* Machine-readable endpoint list. */
  app.get('/api', (_req, res) => {
    res.json({
      name: 'ucp-campus-community-api',
      health: 'GET /api/health',
      posts: 'GET /api/posts?limit=',
      teachers: 'GET /api/teachers?dept=&q=&limit=',
      teacherDetail: 'GET /api/teachers/:slug',
      rateTeacher: 'POST /api/teachers/:slug/rate (auth)',
      stats: 'GET /api/stats',
      stream: 'GET /api/stream (SSE)',
    });
  });

  app.get('/api/health', (_req, res) => {
    res.json({ ok: true, time: new Date(now()).toISOString() });
  });

  /* Who am I (debug/verify-session helper for the app). */
  app.get('/api/me', (req, res) => {
    if (!req.user) return res.status(401).json({ error: 'no session' });
    res.json({ user: req.user });
  });

  app.use('/api', postsRoutes.routes({ config, requireUser }));
  app.use('/api', teachersRoutes.routes({ config, requireUser }));
  app.use('/api', commentsRoutes.routes({ config, requireUser }));
  app.use('/api', uploadRoutes.routes({ config, requireUser }));
  app.use('/api', statsRoutes.routes({ config }));

  /* Server-sent events: one line per mutation; clients refetch on any. */
  app.get('/api/stream', (req, res) => {
    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      Connection: 'keep-alive',
    });
    res.write(': connected\n\n');
    events.addClient(res);
    const heartbeat = setInterval(() => {
      try {
        res.write(': ping\n\n');
      } catch (_) {
        clearInterval(heartbeat);
      }
    }, 25000);
    req.on('close', () => {
      clearInterval(heartbeat);
      events.removeClient(res);
    });
  });

  /* 404 + error shape. */
  // eslint-disable-next-line no-unused-vars
  app.use('/api/', (_req, res) => {
    res.status(404).json({ error: 'unknown endpoint' });
  });

  return app;
}

module.exports = { createApp };
