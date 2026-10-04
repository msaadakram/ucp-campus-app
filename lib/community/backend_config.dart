/// Node API base URL (no trailing slash). Defaults to the production
/// Vercel deployment; override per-build with
/// `--dart-define=NODE_API_URL=...` (e.g. emulator-local testing).
/// This URL is public (not a secret) — all secrets stay server-side.
/// The community system talks ONLY to this backend; the app holds no
/// database credentials at all.
const nodeApiUrl = String.fromEnvironment(
  'NODE_API_URL',
  defaultValue: 'https://ucp-community-api.vercel.app',
);

/// True when the app should use the Node backend.
bool get isNodeConfigured =>
    nodeApiUrl.startsWith('http') && nodeApiUrl.length > 10;

/// Supabase project for teacher reviews (public read via publishable key).
/// Writes still go through the Node API (Odoo-verified), so the secret key
/// never ships in the app. Configure with:
/// `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

/// True when direct Supabase read-fallback is available (public data only).
bool get isSupabaseConfigured =>
    supabaseUrl.startsWith('http') && supabaseAnonKey.length > 20;
