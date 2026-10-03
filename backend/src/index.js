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

  app.get('/api/health', (_req, res) => {
    res.json({ ok: true, time: new Date(now()).toISOString() });
  });

  /* Who am I (debug/verify-session helper for the app). */
  app.get('/api/me', (req, res) => {
    if (!req.user) return res.status(401).json({ error: 'no session' });
    res.json({ user: req.user });
  });

  app.use('/api', postsRoutes.routes({ config, requireUser }));
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
