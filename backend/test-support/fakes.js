'use strict';

/* Shared fakes: chainable postgrest-style query builder + canned tables. */

function makeRows() {
  return {
    community_posts: [
      {
        id: '11111111-1111-1111-1111-111111111111',
        author_email: 'sara@ucp.edu.pk',
        author_name: 'sara',
        title: 'Study group?',
        body: 'Library Thursday',
        flair: 'Study',
        image_url: null,
        created_at: new Date(Date.now() - 12 * 60000).toISOString(),
      },
    ],
    community_comments: [],
    community_votes: [],
    community_comment_votes: [],
    teachers: [
      {
        slug: 'usman-aamer',
        name: 'Usman Aamer',
        designation: 'Lecturer',
        department_code: 'foit',
        department_name: 'Faculty of Information and Technology',
        department_id: 3,
        image_url: 'https://ucp.edu.pk/x.jpg',
        bio: '',
        overall_rating: 4.7,
        review_count: 2,
        grading_pct: 94,
        leniency_pct: 94,
        subject_pct: 94,
        avg_grading: 4.7,
        avg_leniency: 4.7,
        avg_subject: 4.7,
        profile_url: 'https://www.studentspace.site/faculty/usman-aamer',
        updated_at: new Date().toISOString(),
      },
    ],
    teacher_reviews: [],
  };
}

class FakeQuery {
  constructor(tables, table) {
    this.tables = tables;
    this.table = table;
    this.rows = [...(tables[table] || [])];
    this.inserted = null;
    this.upserted = null;
    this.deleted = 0;
  }

  select() {
    return this;
  }

  order(key, { ascending }) {
    this.rows.sort((a, b) =>
      ascending
        ? String(a[key]).localeCompare(String(b[key]))
        : String(b[key]).localeCompare(String(a[key])),
    );
    return this;
  }

  limit(n) {
    this.rows = this.rows.slice(0, n);
    return this;
  }

  eq(k, v) {
    this.rows = this.rows.filter((r) => String(r[k]) === String(v));
    return this;
  }

  ilike(k, pattern) {
    const sub = String(pattern).replace(/%/g, '').toLowerCase();
    this.rows = this.rows.filter((r) =>
      String(r[k] ?? '').toLowerCase().includes(sub),
    );
    return this;
  }

  not(k, op, v) {
    if (v === null) {
      this.rows = this.rows.filter((r) => r[k] !== null);
    }
    return this;
  }

  update(patch) {
    // Deferred so .update().eq() and .eq().update() both work.
    this._patch = patch;
    return this;
  }

  in(col, arr) {
    const set = new Set(arr.map(String));
    this.rows = this.rows.filter((r) => set.has(String(r[col])));
    return this;
  }

  insert(row) {
    const full = {
      id: '99999999-9999-9999-9999-999999999999',
      created_at: new Date().toISOString(),
      ...row,
    };
    this.tables[this.table].push(full);
    this.inserted = full;
    return this;
  }

  upsert(row) {
    this.upserted = row;
    return this;
  }

  delete() {
    this.deleted += 1;
    return this;
  }

  async single() {
    if (this._patch) {
      for (const r of this.rows) Object.assign(r, this._patch);
      const row = this.inserted || this.upserted || this.rows[0] || null;
      if (!row) return { data: null, error: { message: 'none' } };
      return { data: { ...row }, error: null };
    }
    const row = this.inserted || this.upserted || this.rows[0] || null;
    if (!row) return { data: null, error: { message: 'none' } };
    return { data: { ...row }, error: null };
  }

  async maybeSingle() {
    const row = this.rows[0] || null;
    return { data: row ? { ...row } : null, error: null };
  }

  then(resolve) {
    if (this._patch) {
      for (const r of this.rows) Object.assign(r, this._patch);
    }
    resolve({ data: this.rows.map((r) => ({ ...r })), error: null });
  }
}

function makeSupabase(tables) {
  return {
    from: (table) => new FakeQuery(tables, table),
    storage: {
      from: () => ({
        upload: async () => ({ error: null }),
        getPublicUrl: (path) => ({
          data: { publicUrl: `https://cdn.test/${path}` },
        }),
      }),
    },
  };
}

const authedVerify = async () => ({
  uid: 7,
  email: 'tester@ucp.edu.pk',
  name: 'tester',
});

const anonVerify = async () => null;

module.exports = { makeRows, makeSupabase, authedVerify, anonVerify };
