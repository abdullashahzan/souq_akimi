# GitHub distribution

## Android

Download `Souq-Akimi-Android.apk` from the official GitHub Releases page, verify
`SHA256SUMS.txt`, open it and approve Android's per-browser install permission.
Disable that permission afterwards if desired. No store/payment account is
needed. Future updates are manual downloads from this same repository.

- **Souq Akimi 1.0.0 (2)**, package **com.souqakimi.app**.
- Dedicated RSA-4096 release key, not debug signing.
- Certificate SHA-1: `F4:82:44:B3:DC:9B:F6:B5:1C:13:61:0F:7C:59:2D:50:50:38:37:35`.
- New Firebase Android/iOS registrations match the production identifiers.
  Existing Firebase accounts and real data are retained.
- The old `com.example.souq_akimi` development app is a separate install; sign
  in again in the public app. Do not delete your Firebase account to upgrade.
- Shared-key AI is absent. Manual forms, bilingual UI, photos, Google/email
  login, COD and administrator tools remain available.
- Live demos and the temporary QA message were removed using exact IDs and
  timestamp preconditions after a private baseline backup. Unrelated documents
  were exactly preserved. Developer seeders and sample image bundles were removed.
  Legacy unavailable-record guards and automated fixtures do not create demos.

### Signing and building

Private configuration: `~/.config/souq-akimi/release/signing.json`, alongside
`android-release.jks`. **Back up both privately. Losing the signing key prevents
compatible updates. Never commit or upload these files to a public release.**

Configuration shape (values are private, examples are placeholders):

```json
{"storeFile":"/private/path/android-release.jks","storePassword":"PRIVATE","keyAlias":"souq-akimi","keyPassword":"PRIVATE"}
```

Set `SOUQ_SIGNING_CONFIG` to use another private file. With Flutter 3.47.7,
Android SDK and JDK 17:

```sh
flutter pub get
flutter analyze
flutter test
python3 scripts/build_release.py
```

The script supplies signing credentials through the process environment, not
command arguments, and never loads `dart_defines.json`. Gradle refuses missing
release credentials instead of silently using a debug key. The artifact scanner
checks archive members for Groq credentials, private keys and known demo assets.
Also verify `apksigner verify --verbose --print-certs` before uploading.

Deploy the release's Firestore rules before distributing the binary. The new
stock/code protocol and private-profile rules deliberately reject unsafe writes
from old development clients. Do not replace them with permissive rules.

## iOS

GitHub's macOS runner can compile for physical iOS devices. The manual
`iOS unsigned build` workflow packages `Payload/Runner.app` into an unsigned IPA.
If attached to a release, its name remains **Souq-Akimi-iOS-unsigned.ipa**.

**It is not directly installable on ordinary iPhones/iPads.** Opening it from
Safari/Files does not install it. An experienced user needs their own Apple
signing/provisioning and compatible personal-sideload tooling, or a developer
needs Mac/Xcode and a provisioned device. Personal signatures expire and may
need regular renewal. Changing identifiers can require Firebase/OAuth changes.
No Apple certificate, team or device provisioning was supplied, and unsigned
compilation does not establish real-device testing or App Store readiness.

No Apple signing restrictions are bypassed. A genuinely tap-to-install public
iOS release needs a separately arranged Apple-approved distribution route.
No App Store, TestFlight, enterprise enrollment or paid service is configured.

## Support and limits

See [privacy/contact/removal](privacy.md). Report non-private bugs through GitHub
Issues. Use email for moderation and account/data removal. Never post passwords,
delivery codes, phone/room information, signing credentials or keys in Issues.

Spark quotas still apply. Reliable closed-app push, public AI, comprehensive
automated privacy erasure and backend abuse throttling remain outside this
GitHub-only release. A successful compile is not an independent security audit.
