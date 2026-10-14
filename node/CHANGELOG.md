## 1.0.0

- First release, versioned with `dart_wing` and `kechankrisna/php_wing`
  1.0.0 and feature-equal to them: `authorize` (encrypted payload and hash,
  Wing's payment page), `confirmUrl`, `inquiry` (with `isPaid(price)`), and
  `decryptCallback` / `parseCallback`.
- Payloads, hashes and callbacks reproduce the known answers in
  `spec/test-vectors`.
- Typed `WingError` (`type`, `isRetryable`); Wing business errors are
  returned in `status`.
- Injectable `fetch`, clock, `rand_str` source, crypto and logger;
  `AbortSignal` and timeout.
