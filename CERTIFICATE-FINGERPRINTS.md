# UCP Campus — signing certificate fingerprints (public, safe to share)

These are PUBLIC certificate fingerprints, not private keys. The private
half (the keystore) is NEVER committed to this repo and must never leave
the developer machine. Anyone with the private key can sign release builds
as this app; the fingerprints only let you verify builds came from the
right key.

## App identity
- Package: `com.ucpuniversity`
- Play app id: `4973156704245568451`

## Upload key — CURRENT (regenerated 2026-11-21)
The build machine was reset and the previous upload keystore
(`8E:AD:3C:7E:…`, valid 2026-11-09 → 2056-11-01) was lost with it.
A replacement upload key was generated on 2026-11-21.

- Owner: `CN=UCP Campus, OU=UCP Community, O=UCP, L=Lahore, ST=Punjab, C=PK`
- Validity: Nov 21 2026 → Nov 13 2056
- SHA-1:   `99:3A:4B:CC:93:90:8B:5C:58:9E:11:12:3C:DB:87:26:1A:B7:50:65`
- SHA-256: `D2:72:0B:8D:A5:84:91:C9:72:A2:55:40:70:CF:CE:7E:51:7C:93:D7:4D:74:8B:E7:5C:3D:CE:5F:FC:D3:A7:3D`
- Signature algorithm: `SHA256withRSA` (2048-bit)
- Public certificate: `signing/ucp-upload-cert.pem` (safe to share/upload)

**ACTION REQUIRED before the next Play upload:** Play Console →
**App integrity** → **Upload key certificate** → **Request upload key
reset** → upload `signing/ucp-upload-cert.pem`, then upload the AAB signed
with this key. The app-signing key stays with Google, so already-installed
users are unaffected by the reset.

Expected on every release AAB/APK — verify with:
`apksigner verify --print-certs app-release.apk` (SHA-256 digest line),
`keytool -printcert -jarfile app-release.aab`

## Upload key — PREVIOUS (lost 2026-11-21, no longer usable)
- SHA-1:   `3B:4B:6A:AC:4F:D4:08:8D:06:A9:1F:61:E7:C5:AD:06:67:24:40:0A`
- SHA-256: `8E:AD:3C:7E:74:05:8A:B6:DC:A7:DD:25:4C:07:E1:EC:3F:E2:F9:73:A5:0A:A1:70:B6:7E:7F:40:5D:16:6E:10`
- Valid 2026-11-09 → 2056-11-01. Signed the public releases up to
  1.0.54+56 (still downloadable from GitHub Releases, still valid for
  users who installed them).

## App signing key (held by Google — Play App Signing)
- SHA-256: `80:9C:FD:7C:69:10:01:63:BD:1B:D5:AE:03:B0:0F:50:23:31:DC:C1:97:66:5F:AF:AB:37:21:C4:B1:33:F8:CD`
- SHA-1:   `B3:BE:3C:0E:39:7F:E5:5A:27:85:16:D9:0B:AA:11:F9:62:16:05:50`
- Note: Google owns this private key; it signs the APK that reaches
  users' devices. You cannot and never need to sign with it yourself.
- Published by Play in the Digital Asset Links JSON.

## Private material that must NEVER be in this repo
- `ucp-release.keystore` / any `.keystore` / `.jks` / `.p12`
- The *private* key file (a `.pem` that contains `BEGIN PRIVATE KEY` —
  the `signing/ucp-upload-cert.pem` in this repo is only the PUBLIC
  certificate and is safe)
- Any `.env` file with real values (Supabase service role, MONGODB_URI,
  EXT_API_KEY holder values)

Verified 2026-11-21: no private key material is tracked in this repository.
