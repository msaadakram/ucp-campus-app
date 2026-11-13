# UCP Campus — signing certificate fingerprints (public, safe to share)

These are PUBLIC certificate fingerprints, not private keys. The private
half (the keystore / pem) is NEVER committed to this repo and must never
leave the developer machine. Anyone with the private key can sign release
builds as this app; the fingerprints only let you verify builds came from
the right key.

## App identity
- Package: `com.ucpuniversity`
- Play app id: `4973156704245568451`

## Upload key (Play has this registered; resets accepted 2026-11-09)
- Owner: `CN=UCP Campus, OU=UCP Community, O=UCP, L=Lahore, ST=Punjab, C=PK`
- Validity: Nov 09 2026 → Nov 01 2056
- SHA-1:   `3B:4B:6A:AC:4F:D4:08:8D:06:A9:1F:61:E7:C5:AD:06:67:24:40:0A`
- SHA-256: `8E:AD:3C:7E:74:05:8A:B6:DC:A7:DD:25:4C:07:E1:EC:3F:E2:F9:73:A5:0A:A1:70:B6:7E:7F:40:5D:16:6E:10`
- Signature algorithm: `SHA256withRSA` (2048-bit)
- Expected on every release AAB/APK — verify with:
  `apksigner verify --print-certs app-release.apk` (SHA-256 digest line),
  `keytool -printcert -jarfile app-release.aab`

## App signing key (held by Google — Play App Signing)
- SHA-256: `80:9C:FD:7C:69:10:01:63:BD:1B:D5:AE:03:B0:0F:50:23:31:DC:C1:97:66:5F:AF:AB:37:21:C4:B1:33:F8:CD`
- SHA-1:   `B3:BE:3C:0E:39:7F:E5:5A:27:85:16:D9:0B:AA:11:F9:62:16:05:50`
- Note: Google owns this private key; it signs the APK that reaches
  users' devices. You cannot and never need to sign with it yourself.
- Published by Play in the Digital Asset Links JSON.

## Private material that must NEVER be in this repo
- `ucp-release.keystore` / any `.keystore` / `.jks` / `.p12`
- `ucp-upload-key.pem` (the upload key *private* material)
- Any `.env` file with real values (Supabase service role, MONGODB_URI,
  EXT_API_KEY holder values)

Verified 2026-11-11: no private key material is tracked in this repository
(see git history scan: no keystores, no pem, no `BEGIN PRIVATE KEY` blocks).
