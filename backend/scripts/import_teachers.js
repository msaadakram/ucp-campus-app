'use strict';

/* Bulk import of StudentSpace parsed data into Supabase.
 * Usage:
 *   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... \
 *     node scripts/import_teachers.js ../../teachers.json ../../reviews.json
 * Defaults to <repo>/teachers.json + reviews.json (the scrape output).
 */

const fs = require('fs');
const path = require('path');
const { createClient } = require('@supabase/supabase-js');

async function main() {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) {
    console.error('Missing SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY');
    process.exit(1);
  }
  const teachersPath =
    process.argv[2] || path.join(__dirname, '..', '..', 'teachers.json');
  const reviewsPath =
    process.argv[3] || path.join(__dirname, '..', '..', 'reviews.json');
  const teachers = JSON.parse(fs.readFileSync(teachersPath, 'utf8'));
  const reviews = JSON.parse(fs.readFileSync(reviewsPath, 'utf8'));
  const db = createClient(url, key);

  console.log(`Upserting ${teachers.length} teachers...`);
  const rows = teachers.map((t) => ({
    slug: t.slug,
    name: t.name || t.slug,
    designation: t.designation || '',
    department_code: t.department_code || '',
    department_name: t.department_name || '',
    department_id: Number(t.department_id) || 0,
    image_url: t.image_url || '',
    bio: t.bio || '',
    overall_rating: Number(t.overall_rating) || 0,
    review_count: Number(t.review_count_actual ?? t.review_count_json) || 0,
    grading_pct: Number(t.grading_pct) || 0,
    leniency_pct: Number(t.leniency_pct) || 0,
    subject_pct: Number(t.subject_pct) || 0,
    avg_grading: Number(t.avg_grading) || 0,
    avg_leniency: Number(t.avg_leniency) || 0,
    avg_subject: Number(t.avg_subject) || 0,
    profile_url: t.url || `https://www.studentspace.site/faculty/${t.slug}`,
  }));
  for (let i = 0; i < rows.length; i += 200) {
    const chunk = rows.slice(i, i + 200);
    const { error } = await db.from('teachers').upsert(chunk, {
      onConflict: 'slug',
    });
    if (error) throw error;
    console.log(`  teachers ${Math.min(i + 200, rows.length)}/${rows.length}`);
  }

  console.log(`Inserting ${reviews.length} reviews (skipping existing source_id)...`);
  const { data: existing } = await db
    .from('teacher_reviews')
    .select('source_id')
    .not('source_id', 'is', null);
  const seen = new Set((existing || []).map((r) => Number(r.source_id)));
  const fresh = reviews.filter((r) => !seen.has(Number(r.review_id)));
  console.log(`  ${fresh.length} new reviews to insert`);
  const revRows = fresh.map((r) => ({
    teacher_slug: r.teacher_slug,
    student_name: r.student_name || 'student',
    author_email: '',
    comment: (r.comment || '').slice(0, 2000),
    rating_grading: Math.min(5, Math.max(1, Number(r.rating_grading) || 3)),
    rating_leniency: Math.min(5, Math.max(1, Number(r.rating_leniency) || 3)),
    rating_subject: Math.min(5, Math.max(1, Number(r.rating_subject) || 3)),
    is_blocked: r.is_blocked === 'YES',
    source_id: Number(r.review_id) || null,
  }));
  for (let i = 0; i < revRows.length; i += 200) {
    const chunk = revRows.slice(i, i + 200);
    const { error } = await db.from('teacher_reviews').insert(chunk);
    if (error) throw error;
    console.log(`  reviews ${Math.min(i + 200, revRows.length)}/${revRows.length}`);
  }
  console.log('Import done.');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
