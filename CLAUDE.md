# CLAUDE.md

Wing Bank **online payment** (Web SDK v2) SDKs: Dart (`dart/`), Flutter
widgets (`flutter/`), PHP (`php/` + root `composer.json`), Kotlin
(`kotlin/`) and Node.js (`node/`), with shared known answers in `spec/`.
Commands and releases are in [CONTRIBUTING.md](CONTRIBUTING.md); this file
lists what is easy to get wrong.

## Never commit or expose

- `.env` / `.env.*` files hold Wing usernames, REST API keys and passwords.
  Never commit, print or log them; check `git diff --cached` for secret
  values before committing. Templates must only contain placeholders.
- `.wing-docs/` holds Wing's specification PDF. Read it; never commit it or
  copy its text into the repository. This repository is public.

## Rules

- AES is PHP's `openssl_encrypt($data, 'AES-256-CBC', $password, 0, $iv)`:
  the UTF-8 password NUL-padded or truncated to 32 bytes, PKCS#7, base64
  out. The payload and callback IV is the first 16 bytes of the password;
  the hash IV is `rand_str`.
- `hash` = `UPPERCASE(SHA256(AES(base64(username#rest_api_key#
  bill_till_number#amount#order_reference_no#rand_str#timestamp))))`.
  Amounts are sent with exactly 2 decimals; amounts with more are rejected,
  not rounded.
- The payload JSON keeps the field order of the spec's sample, leaves out
  absent optional fields, and escapes neither `/` nor non-ASCII.
- Check behaviour against `spec/test-vectors/php_known_answers.json`
  instead of trusting the spec's prose; regenerate it with PHP when inputs
  change.
- Wing business errors (`errorCode` other than `200`) are returned in
  `status`; only transport and local failures throw. Logs mask
  `rest_api_key`.
- Inquiry is `v2` (section 4.1 of the spec, confirmed on Wing staging), not
  the `v1` of the spec's endpoint list. The authorization token is opaque
  (not a JWT). Wing staging (`https://stage-pm2.wingbank.com`) serves the API
  at its root, without `/wingonlinesdkv2`: use the base URL Wing gives as is.
- `flutter/` depends on `dart_wing` ^1.0.0 from pub.dev, not on `dart/` by
  path: a `dart/` change reaches it only after a Dart release.
- `composer.json` must stay at the repository root for Packagist;
  `.gitattributes` keeps the other SDKs out of the Composer archive.
- Kotlin (`kotlin/`) is JVM-only and server-side. Keep `VERSION_NAME` in
  `kotlin/gradle.properties` and `WingService.SDK_VERSION` equal (a test
  checks); publishing credentials come only from environment variables.
- Dart: after editing an annotated model, run
  `dart run build_runner build --delete-conflicting-outputs` and commit the
  `*.g.dart` files. CI resolves with `dart pub get --no-example`.
