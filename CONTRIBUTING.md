# Contributing

## Layout

| Folder | Package | Tooling |
|---|---|---|
| `spec/` | shared known answers (`spec/test-vectors/`) | PHP to regenerate |
| `dart/` | `dart_wing` | Dart 3.9+ |
| `flutter/` | `flutter_wing` | Flutter |
| `php/` + `composer.json` | `kechankrisna/php_wing` | PHP, Composer |
| `kotlin/` | `io.github.kechankrisna:wing-onlinepayment` | JDK 17+, Gradle wrapper |
| `node/` | `@kechankrisna/wing-onlinepayment` | Node.js 22+, npm |

## Secrets

UAT credentials go in `.env` files next to each SDK (copy its
`.env.example`). **Never commit a `.env` file.** The root `.gitignore`
ignores every `.env` and `.env.*` except the templates. Keep Wing's
documentation in `.wing-docs/` (ignored): it is not ours to publish.

## Tests

Dart: formatting, analysis, offline tests, then integration tests. The
integration tests use `dart/.env`, or the file named by `WING_ENV_FILE`
(e.g. `WING_ENV_FILE=.env.production`). They authorize a 0.10 USD payment,
so a file with `WING_SANDBOX="0"` is refused unless
`WING_ALLOW_PRODUCTION=true`.

```sh
cd dart
dart pub get
dart format lib test
dart analyze --fatal-infos
dart test -x integration
dart test
```

Flutter (offline widget tests with a fake web view):

```sh
cd flutter
flutter pub get
dart format lib test example/lib example/test
flutter analyze --fatal-infos
flutter test
(cd example && flutter pub get && flutter test)
```

Flutter live tests: open Wing's real payment page in a real web view, with
the credentials of `flutter/example/.env` (copy its `.env.example`). Run
`flutter create --platforms macos .` in `flutter/example` once (the
generated `macos/` is ignored) and add the
`com.apple.security.network.client` entitlement to both
`macos/Runner/*.entitlements` (see `flutter/example/README.md`):

```sh
cd flutter/example
flutter test integration_test -d macos --dart-define-from-file=.env
```

PHP (from the repository root):

```sh
composer install
composer test:unit   # offline, includes the known answers
composer analyse     # PHPStan, level max
composer cs          # coding style (composer cs:fix to apply)
composer test        # also runs the integration tests if php/.env exists
```

Kotlin (compile with warnings as errors, ktlint, offline tests; integration
tests read `kotlin/.env` or `WING_ENV_FILE`, like Dart):

```sh
cd kotlin
./gradlew build            # ./gradlew ktlintFormat fixes formatting
./gradlew integrationTest
```

Node.js (offline tests; `npx vitest run test/integration.test.ts` runs the
integration tests with `node/.env`, same rules as Dart):

```sh
cd node
npm ci
npm run typecheck && npm run lint && npm run format:check
npm run test:unit
npm run build
```

## Known answers

`spec/test-vectors/php_known_answers.php` encrypts and hashes fixed inputs
with PHP's `openssl_encrypt`, as in Wing's spec. Regenerate the JSON when
inputs change:

```sh
php spec/test-vectors/php_known_answers.php > spec/test-vectors/php_known_answers.json
```

Every SDK should reproduce these payloads, hashes and callbacks.

## Releasing

| SDK | Bump | Publish |
|---|---|---|
| Dart | `dart/pubspec.yaml`, `dart/lib/src/version.dart`, `dart/CHANGELOG.md` | push tag `dart-vX.Y.Z`; `.github/workflows/release-dart.yml` publishes |
| Flutter | `flutter/pubspec.yaml`, `flutter/CHANGELOG.md` | push tag `flutter-vX.Y.Z`; `.github/workflows/release-flutter.yml` publishes |
| PHP | `php/src/Version.php`, `php/CHANGELOG.md`, then tag `vX.Y.Z` | Packagist reads the tag (composer.json at the root) |
| Kotlin | `kotlin/gradle.properties` (`VERSION_NAME`), `SDK_VERSION` in `WingService.kt`, `kotlin/CHANGELOG.md` | push tag `kotlin-vX.Y.Z`; `.github/workflows/release-kotlin.yml` publishes to Maven Central |
| Node.js | `node/package.json`, `node/src/version.ts`, `node/CHANGELOG.md` | push tag `node-vX.Y.Z`; `.github/workflows/release-node.yml` publishes |

Plain `v*` tags are PHP releases; use prefixed tags (e.g. `dart-v1.0.1`) for
the others. Packagist ignores tags that do not parse as versions.

`flutter_wing` depends on `dart_wing` from pub.dev: release a `dart/`
change before the `flutter/` change that needs it.

One-time setup for Dart and Flutter: on pub.dev, the package → Admin →
Automated publishing → GitHub Actions, repository
`kechankrisna/wing-onlinepayment`, tag pattern `dart-v{{version}}`
(dart_wing) or `flutter-v{{version}}` (flutter_wing). The first version of
a new package must be published by hand (`dart pub publish`).

One-time setup for Kotlin: on central.sonatype.com, verify the namespace
`io.github.kechankrisna` and generate a user token; create a GPG signing key
and publish its public key to a keyserver; then add the repository secrets
`MAVEN_CENTRAL_USERNAME`, `MAVEN_CENTRAL_PASSWORD` (the token),
`SIGNING_KEY` (ASCII-armored private key) and `SIGNING_PASSWORD`.

One-time setup for Node.js (npm trusted publishing, no token): on
npmjs.com, `@kechankrisna/wing-onlinepayment` → Settings → Trusted
publishing → GitHub Actions, repository `kechankrisna/wing-onlinepayment`,
workflow `release-node.yml`.

Optional: the repository secret `WING_UAT_ENV` (the content of a UAT
`.env`) makes CI run the integration tests.
