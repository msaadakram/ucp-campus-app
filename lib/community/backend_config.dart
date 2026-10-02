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
