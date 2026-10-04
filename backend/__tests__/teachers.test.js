'use strict';

process.env.NODE_ENV = 'test';

const request = require('supertest');
const { createApp } = require('../src/index');
const { __setClient, __resetClient } = require('../src/supabase');
const { __reset } = require('../src/events');
const { makeRows, makeSupabase, authedVerify, anonVerify } = require('../test-support/fakes');

const config = {
  port: 0,
  supabaseUrl: 'https://x.supabase.co',
  supabaseServiceKey: 'test-key',
  odooBase: 'https://horizon.ucp.edu.pk',
  corsOrigin: '*',
};

function appWith(tables, verify) {
  __resetClient();
  __reset();
  __setClient(makeSupabase(tables));
  return createApp({ config, verify, enableRateLimit: false });
}

describe('teachers', () => {
  test('list returns seeded teacher, filters by dept and q', async () => {
    const app = appWith(makeRows(), anonVerify);
    const all = await request(app).get('/api/teachers').expect(200);
    expect(all.body.teachers).toHaveLength(1);
    expect(all.body.teachers[0].slug).toBe('usman-aamer');

    const foit = await request(app).get('/api/teachers?dept=foit').expect(200);
    expect(foit.body.teachers).toHaveLength(1);

    const none = await request(app).get('/api/teachers?dept=fol').expect(200);
    expect(none.body.teachers).toHaveLength(0);

    const q = await request(app).get('/api/teachers?q=usman').expect(200);
    expect(q.body.teachers).toHaveLength(1);

    const qMiss = await request(app).get('/api/teachers?q=zzz').expect(200);
    expect(qMiss.body.teachers).toHaveLength(0);
  });

  test('detail returns teacher + reviews, 404 on unknown slug', async () => {
    const app = appWith(makeRows(), anonVerify);
    const res = await request(app).get('/api/teachers/usman-aamer').expect(200);
    expect(res.body.teacher.name).toBe('Usman Aamer');
    expect(res.body.reviews).toEqual([]);
    await request(app).get('/api/teachers/no-such-teacher').expect(404);
    await request(app).get('/api/teachers/BAD_SLUG!!').expect(400);
  });

  test('rate requires session, validates 1..5, recomputes stats', async () => {
    const app = appWith(makeRows(), anonVerify);
    await request(app)
      .post('/api/teachers/usman-aamer/rate')
      .send({ grading: 5, leniency: 5, subject: 5 })
      .expect(401);

    const authed = appWith(makeRows(), authedVerify);
    const hdr = { 'x-ucp-session': 'live-sid' };
    await request(authed)
      .post('/api/teachers/usman-aamer/rate')
      .set(hdr)
      .send({ grading: 7, leniency: 5, subject: 5 })
      .expect(400);
    await request(authed)
      .post('/api/teachers/usman-aamer/rate')
      .set(hdr)
      .send({ grading: 5, leniency: 5, subject: 5, comment: 'x'.repeat(2001) })
      .expect(400);

    const ok = await request(authed)
      .post('/api/teachers/usman-aamer/rate')
      .set(hdr)
      .send({ grading: 5, leniency: 4, subject: 3, comment: 'Good teacher' })
      .expect(201);
    expect(ok.body.review.rating_grading).toBe(5);
    expect(ok.body.stats.n).toBe(1);

    const detail = await request(authed)
      .get('/api/teachers/usman-aamer')
      .expect(200);
    expect(detail.body.reviews).toHaveLength(1);
    expect(detail.body.teacher.review_count).toBe(1);
  });
});

describe('teachers validate helpers', () => {
  const t = require('../src/routes/teachers');
  test('clampRating / cleanSlug / cleanComment', () => {
    expect(t.clampRating(5)).toBe(5);
    expect(t.clampRating(0)).toBeNull();
    expect(t.clampRating(7)).toBeNull();
    expect(t.cleanSlug('Usman-Aamer')).toBe('usman-aamer');
    expect(t.cleanSlug('bad!!')).toBeNull();
    expect(t.cleanComment('  hi  ')).toBe('hi');
    expect(t.cleanComment('')).toBe('');
    expect(t.cleanComment('x'.repeat(2001))).toBeNull();
  });
});
