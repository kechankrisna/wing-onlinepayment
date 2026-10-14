# Changelog

## 1.0.0

First release of `kechankrisna/php_wing`, the PHP twin of `dart_wing` 1.0.0,
for Wing Bank's online payment Web SDK v2 (spec 2.0.3).

- `authorize()`: encrypts the payment (AES-256-CBC `payload`) and signs it
  (`hash`); returns the token and Wing's payment page (`confirmUrl`).
  `WebApp` (return URL) and `MobileApp` (deep link) integrations.
- `inquiry()`: transaction details, with `isPaid($price)` to reject amounts
  below your price as Wing requires.
- `decryptCallback()` / `parseCallback()`: decrypt the `contents` Wing POSTs
  to your callback URL.
- Payloads, hashes and callbacks reproduce the known answers in
  `spec/test-vectors`.
- Wing business errors are returned in `status`; transport and local
  failures throw `WingException` with an `ErrorType` and `isRetryable()`.
- Default HTTP client on ext-curl; any PSR-18 client can be injected, plus a
  PSR-20 clock, a PSR-3 logger (REST API key masked) and a `WingCrypto`.
