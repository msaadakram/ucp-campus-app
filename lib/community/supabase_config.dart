/// Supabase connection for the live community backend.
///
/// Fill these in (see supabase/README.md), then rebuild. Values may also
/// come from `--dart-define` (preferred: secrets never touch git):
///
///   flutter build apk --release \
///     --dart-define=SUPABASE_URL=https://xyz.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJhbG...
///
/// The anon key is a PUBLIC key by design (it ships inside every Supabase
/// app); row-level policies in supabase/schema.sql bound what it can do.
const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: '',
);

const supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: '',
);

/// True once real credentials are present (build flavor or edited file).
bool get isSupabaseConfigured =>
    supabaseUrl.startsWith('https://') && supabaseAnonKey.length > 20;

/// Node API base (no trailing slash), e.g. `https://api.ucp.edu.pk` or for
/// the Android emulator `http://10.0.2.2:3001`. Empty = not configured.
/// Prefer `--dart-define=NODE_API_URL=...` so it never lands in git.
const nodeApiUrl = String.fromEnvironment(
  'NODE_API_URL',
  defaultValue: '',
);

/// True when the app should talk to the Node backend (takes precedence
/// over direct Supabase access).
bool get isNodeConfigured =>
    nodeApiUrl.startsWith('http') && nodeApiUrl.length > 10;
