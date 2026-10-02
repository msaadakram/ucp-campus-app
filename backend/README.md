# UCP Campus community API (Node.js)

Express API between the Flutter app and Supabase. The app never touches
Supabase directly in this mode: every write carries the student's Horizon
portal `session_id`, which this server verifies against Odoo before doing
anything. Author identity always comes from that verified session — the
client cannot post, vote or comment as anyone else.

## Run it

```bash
cd backend
cp .env.example .env        # then fill SUPABASE_URL + SERVICE_ROLE key
npm install
npm test                    # 14 route/auth/upload tests, no network
npm start                   # → http://localhost:3001
```

Production: `node src/server.js` behind anything (systemd/pm2/docker),
`PORT` env respected. Needs outbound HTTPS to Supabase + Horizon.

## Auth model

- Header `x-ucp-session: <session_id>` (query `?session_id=` also works).
- `attachUser` resolves it via Odoo `POST /web/session/get_session_info`.
  Dead/unknown session → `req.user = null`.
- Reads (`GET /api/posts`, thread, `/api/health`, `/api/stream`) are open;
  without a session, "my vote" fields just come back 0.
- Every write goes through `requireUser` → otherwise `401`.

## Endpoints

| Method | Path | Auth | Body / notes |
|---|---|---|---|
| GET | `/api/health` | — | `{ok, time}` |
| GET | `/api/me` | session | echoes verified `{uid, email, name}` |
| GET | `/api/posts?limit=` | optional | newest first; each post has `score` (excl. my vote), `vote`, `commentCount`, embedded flat `comments[]` |
| POST | `/api/posts` | required | `{title 1..120, body ≤2000, flair, imageUrl?}` → 201 |
| POST | `/api/posts/:id/vote` | required | `{value: 1\|-1}` sets; `{}` clears |
| GET | `/api/posts/:id/comments` | optional | flat rows `{id,parent_id,author_name,text,created_at,score,vote}` |
| POST | `/api/posts/:id/comments` | required | `{text 1..2000, parentId?}` (parent must belong to post) → 201 |
| POST | `/api/comments/:id/vote` | required | same contract as post votes |
| POST | `/api/upload` | required | multipart `image` (jpeg/png/webp/gif, ≤5 MB) → 201 `{url, path}` |
| GET | `/api/stream` | optional | SSE `community-changed` events + `:ping` keepalive |

Scores exclude the viewer's own vote everywhere (the app renders
`score + vote`), same convention as the rest of the system.

## Live updates

Mutations broadcast to SSE clients (`src/events.js`, in-process fan-out —
fine for one instance; use Redis pub/sub past that). Clients refetch the
feed on any event (debounced app-side too).

## Rate limits / hardening

`helmet`, JSON ≤256 KB, 300 req/15 min global, 30 uploads/15 min. CORS open
(`CORS_ORIGIN=*`) for the mobile pilot — set explicit origins if you ever
serve this API to browsers.

## Testing

`npm test` — jest + supertest against injected fakes (no network, no DB):
auth gating, feed aggregation, identity override rejection, validation
400s, nested replies, parent-graft rejection, upload accept/reject.
