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

describe('auth', () => {
  test('GET / shows a browser landing page, not a 404', async () => {
    const app = appWith(makeRows(), anonVerify);
    const res = await request(app).get('/').expect(200);
    expect(res.text).toContain('UCP Campus API');
    expect(res.text).toContain('/api/teachers');
  });

  test('GET /api lists endpoints as JSON', async () => {
    const app = appWith(makeRows(), anonVerify);
    const res = await request(app).get('/api').expect(200);
    expect(res.body.teachers).toContain('/api/teachers');
    expect(res.body.health).toBe('GET /api/health');
  });

  test('GET /api/me is 401 without a session', async () => {
    const app = appWith(makeRows(), anonVerify);
    await request(app).get('/api/me').expect(401);
  });

  test('GET /api/me resolves identity from the Odoo session', async () => {
    const app = appWith(makeRows(), authedVerify);
    const res = await request(app)
      .get('/api/me')
      .set('x-ucp-session', 'live-sid')
      .expect(200);
    expect(res.body.user.email).toBe('tester@ucp.edu.pk');
  });

  test('writes without a session are 401', async () => {
    const app = appWith(makeRows(), anonVerify);
    await request(app).post('/api/posts').send({ title: 'x' }).expect(401);
  });
});

describe('posts', () => {
  test('feed lists posts with scores, votes and comment counts', async () => {
    const tables = makeRows();
    tables.community_votes.push(
      { post_id: tables.community_posts[0].id, author_email: 'a@x', value: 1 },
      { post_id: tables.community_posts[0].id, author_email: 'a@x', value: 1 },
      {
        post_id: tables.community_posts[0].id,
        author_email: 'tester@ucp.edu.pk',
        value: -1,
      },
    );
    tables.community_comments.push({
      id: 'c1',
      post_id: tables.community_posts[0].id,
    });
    const app = appWith(tables, authedVerify);
    const res = await request(app)
      .get('/api/posts')
      .set('x-ucp-session', 'live-sid')
      .expect(200);
    expect(res.body.posts).toHaveLength(1);
    expect(res.body.posts[0].score).toBe(2); // 1+1-1 total, minus my -1
    expect(res.body.posts[0].vote).toBe(-1);
    expect(res.body.posts[0].commentCount).toBe(1);
  });

  test('create uses the SESSION identity, never the body author', async () => {
    const app = appWith(makeRows(), authedVerify);
    const res = await request(app)
      .post('/api/posts')
      .set('x-ucp-session', 'live-sid')
      .send({
        title: 'Hello campus',
        body: 'first!',
        flair: 'Study',
        author_email: 'evil@x',
        author_name: 'evil',
      })
      .expect(201);
    expect(res.body.post.author).toBe('tester'); // from Odoo, not body
    expect(res.body.post.title).toBe('Hello campus');
  });

  test('create validation: title, flair', async () => {
    const app = appWith(makeRows(), authedVerify);
    const hdr = { 'x-ucp-session': 'live-sid' };
    await request(app)
      .post('/api/posts')
      .set(hdr)
      .send({ title: '', flair: 'Study' })
      .expect(400);
    await request(app)
      .post('/api/posts')
      .set(hdr)
      .send({ title: 'ok', flair: 'Nope' })
      .expect(400);
    await request(app)
      .post('/api/posts')
      .set(hdr)
      .send({ title: 'x'.repeat(121), flair: 'Study' })
      .expect(400);
  });

  test('vote set, clear and bad values', async () => {
    const app = appWith(makeRows(), authedVerify);
    const hdr = { 'x-ucp-session': 'live-sid' };
    const pid = makeRows().community_posts[0].id;
    await request(app)
      .post(`/api/posts/${pid}/vote`)
      .set(hdr)
      .send({ value: 1 })
      .expect(200);
    await request(app)
      .post(`/api/posts/${pid}/vote`)
      .set(hdr)
      .send({})
      .expect(200);
    await request(app)
      .post(`/api/posts/${pid}/vote`)
      .set(hdr)
      .send({ value: 7 })
      .expect(400);
    await request(app)
      .post('/api/posts/not-a-uuid/vote')
      .set(hdr)
      .send({ value: 1 })
      .expect(400);
  });
});

describe('comments', () => {
  const pid = makeRows().community_posts[0].id;

  test('add top-level then nested reply, thread nests', async () => {
    const app = appWith(makeRows(), authedVerify);
    const hdr = { 'x-ucp-session': 'live-sid' };
    const top = await request(app)
      .post(`/api/posts/${pid}/comments`)
      .set(hdr)
      .send({ text: 'top comment' })
      .expect(201);
    expect(top.body.comment.author).toBe('tester');
    await request(app)
      .post(`/api/posts/${pid}/comments`)
      .set(hdr)
      .send({ text: 'nested', parentId: top.body.comment.id })
      .expect(201);
    const thread = await request(app)
      .get(`/api/posts/${pid}/comments`)
      .set(hdr)
      .expect(200);
    // Flat rows: top-level first, reply linked via parentId (client nests).
    expect(thread.body.comments).toHaveLength(2);
    expect(thread.body.comments[0].parentId).toBeNull();
    expect(thread.body.comments[1].parentId).toBe(
      thread.body.comments[0].id,
    );
    // parent grafted to another post is rejected
    await request(app)
      .post(`/api/posts/${pid}/comments`)
      .set(hdr)
      .send({ text: 'x', parentId: '22222222-2222-2222-2222-222222222222' })
      .expect(400);
    // empty text rejected
    await request(app)
      .post(`/api/posts/${pid}/comments`)
      .set(hdr)
      .send({ text: '   ' })
      .expect(400);
  });

  test('comment vote set and clear', async () => {
    const tables = makeRows();
    tables.community_comments.push({
      id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      post_id: pid,
      parent_id: null,
      author_name: 's',
      text: 't',
      created_at: new Date().toISOString(),
    });
    const app = appWith(tables, authedVerify);
    const hdr = { 'x-ucp-session': 'live-sid' };
    await request(app)
      .post('/api/comments/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/vote')
      .set(hdr)
      .send({ value: 1 })
      .expect(200);
    await request(app)
      .post('/api/comments/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/vote')
      .set(hdr)
      .send({})
      .expect(200);
  });
});

describe('upload', () => {
  test('missing file is 400', async () => {
    const app = appWith(makeRows(), authedVerify);
    await request(app)
      .post('/api/upload')
      .set('x-ucp-session', 'live-sid')
      .expect(400);
  });

  test('non-image is 400', async () => {
    const app = appWith(makeRows(), authedVerify);
    await request(app)
      .post('/api/upload')
      .set('x-ucp-session', 'live-sid')
      .attach('image', Buffer.from('not an image'), {
        filename: 'evil.txt',
        contentType: 'text/plain',
      })
      .expect(400);
  });

  test('jpeg under limit returns a public url', async () => {
    const app = appWith(makeRows(), authedVerify);
    const res = await request(app)
      .post('/api/upload')
      .set('x-ucp-session', 'live-sid')
      .attach('image', Buffer.alloc(1024, 7), {
        filename: 'photo.jpg',
        contentType: 'image/jpeg',
      })
      .expect(201);
    expect(res.body.url).toMatch(/^https:\/\/cdn\.test\/posts\//);
  });

  test('upload without session is 401', async () => {
    const app = appWith(makeRows(), anonVerify);
    await request(app)
      .post('/api/upload')
      .attach('image', Buffer.alloc(16), {
        filename: 'a.jpg',
        contentType: 'image/jpeg',
      })
      .expect(401);
  });
});

describe('stats', () => {
  test('counts distinct contributors, online is live SSE count', async () => {
    const tables = makeRows();
    tables.community_comments.push(
      { author_email: 'B@ucp.edu.pk' },
      { author_email: 'sara@ucp.edu.pk' },
    );
    tables.community_votes.push(
      { author_email: 'c@ucp.edu.pk', post_id: 'x', value: 1 },
      { author_email: 'SARA@ucp.edu.pk', post_id: 'x', value: 1 },
    );
    const app = appWith(tables, authedVerify);
    const res = await request(app).get('/api/stats').expect(200);
    // sara (post+comment+vote, case-insensitive) + B + c = 3 members.
    expect(res.body.members).toBe(3);
    expect(res.body.online).toBe(0); // no SSE clients in test
  });

  test('empty backend degrades to zeros, never 500', async () => {
    const app = appWith(
      {
        community_posts: [],
        community_comments: [],
        community_votes: [],
        community_comment_votes: [],
      },
      anonVerify,
    );
    const res = await request(app).get('/api/stats').expect(200);
    expect(res.body).toEqual({ members: 0, online: 0 });
  });
});

describe('validate helpers', () => {
  const v = require('../src/middleware/validate');
  test('uuids, titles, votes', () => {
    expect(v.isUuid('11111111-1111-1111-1111-111111111111')).toBe(true);
    expect(v.isUuid('nope')).toBe(false);
    expect(v.cleanTitle('  hi  ')).toBe('hi');
    expect(v.cleanTitle('')).toBeNull();
    expect(v.cleanVote(1)).toBe(1);
    expect(v.cleanVote(null)).toBeNull();
    expect(v.cleanVote(7)).toBe('invalid');
    expect(v.FLAIRS).toContain('Marketplace');
  });
});
