## 1.0.0

First release: a Dart client for Wing Bank's online payment Web SDK v2
(spec 2.0.3).

- `authorize`: encrypts the payment (AES-256-CBC `payload`) and signs it
  (`hash`), and returns the token and Wing's payment page (`confirmUrl`);
  `WEBAPP` (return URL) and `MOBAPP` (deep link) integrations
- `inquiry`: transaction details, with `isPaid(price)` to reject amounts
  below your price as Wing requires
- `decryptCallback` / `parseCallback`: decrypt the `contents` Wing POSTs to
  your callback URL
- payloads, hashes and callbacks reproduce the known answers computed with
  PHP's `openssl_encrypt` (`spec/test-vectors`)
- Wing business errors are returned in `status`; transport and local
  failures throw `WingException` with a `WingErrorType` and `isRetryable`
