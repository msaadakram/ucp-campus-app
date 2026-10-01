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
