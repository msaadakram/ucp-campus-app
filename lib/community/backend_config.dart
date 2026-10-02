/// Node API base URL (no trailing slash), e.g. `https://api.ucp.edu.pk` or,
/// for the Android emulator against a laptop server, `http://10.0.2.2:3001`.
///
/// Prefer `--dart-define=NODE_API_URL=...` so it never lands in git.
/// The community system talks ONLY to this backend; the app holds no
/// database credentials at all.
const nodeApiUrl = String.fromEnvironment(
  'NODE_API_URL',
  defaultValue: '',
);

/// True when the app should use the Node backend.
bool get isNodeConfigured =>
    nodeApiUrl.startsWith('http') && nodeApiUrl.length > 10;
