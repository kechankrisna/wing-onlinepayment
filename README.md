# Wing Online Payment SDKs

Clients for **Wing Bank's online payment** API (Web SDK v2, spec 2.0.3) in
several languages: authorize a payment, send the payer to Wing's payment
page, confirm it with the inquiry API, and decrypt the callback Wing pushes
after a successful payment.

| Folder | Package | Status |
|---|---|---|
| [`dart/`](dart/README.md) | [`dart_wing`](https://pub.dev/packages/dart_wing) (pub.dev) | 1.0.0: authorization, inquiry, callback decryption, tested against the PHP known answers |
| [`flutter/`](flutter/README.md) | [`flutter_wing_checkout`](https://pub.dev/packages/flutter_wing_checkout) (pub.dev) | 1.0.0: Wing's payment page in a web view, built on `dart_wing` 1.0.0 |
| [`php/`](php/README.md) | [`kechankrisna/php_wing`](https://packagist.org/packages/kechankrisna/php_wing) (Packagist) | 1.0.0: authorization, inquiry, callback decryption, tested against the PHP known answers |
| [`kotlin/`](kotlin/README.md) | `io.github.kechankrisna:wing-onlinepayment` (Maven Central) | 1.0.0: Kotlin/JVM, authorization, inquiry, callback decryption, tested against the PHP known answers |
| [`node/`](node/README.md) | [`@kechankrisna/wing-onlinepayment`](https://www.npmjs.com/package/@kechankrisna/wing-onlinepayment) (npm) | 1.0.0: authorization, inquiry, callback decryption, tested against the PHP known answers |

For ABA PayWay, see
[payway-checkout](https://github.com/kechankrisna/payway-checkout).

## How a payment works

1. Your server calls **authorize** with the order: the SDK encrypts the
   payment into `payload` (AES-256-CBC with your Wing password), signs it
   into `hash`, and Wing returns a token.
2. The payer opens **`confirmUrl`** (Wing's payment page) and pays, in a
   browser, a web view (`flutter_wing_checkout`) or the Wing Bank app.
3. Wing redirects to your `return_url` with `status=success` (or opens your
   app's deep link for `MOBAPP` payments).
4. Your server calls **inquiry** and accepts the payment only if the amount
   is at least your price (`isPaid(price)`), as Wing requires. Wing can also
   POST the payment, encrypted, to a callback URL configured on its side:
   **parseCallback** decrypts it.

`spec/` holds what every SDK must agree on: payloads, hashes and callbacks
computed with PHP's `openssl_encrypt`, the function of the PHP sample in
Wing's spec (`spec/test-vectors/`).

## Tested against Wing

The Dart, PHP, Kotlin and Node.js SDKs pass their integration tests against
Wing's staging server (`https://stage-pm2.wingbank.com`): authorization
succeeds, and inquiry of an unknown order returns `PG-I007` "Reference
number not found". `flutter_wing_checkout` opens Wing's real payment page in a web
view on macOS.

## Where to run it

Call Wing from **your server**: the REST API key and the password are
secrets, and Wing checks the `Referer` header against the domain you
registered.

## Repository layout

```
spec/       shared known answers
dart/       Dart SDK        → pub.dev
flutter/    Flutter widgets → pub.dev
php/        PHP SDK         → Packagist (composer.json is at the root)
kotlin/     Kotlin/JVM SDK  → Maven Central
node/       Node.js SDK     → npm
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for tests and releases.
