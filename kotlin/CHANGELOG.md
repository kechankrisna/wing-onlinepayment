# Changelog

## 1.0.0

First release of `io.github.kechankrisna:wing-onlinepayment`, the Kotlin/JVM
twin of `dart_wing` 1.0.0 and `kechankrisna/php_wing` 1.0.0, for Wing
Bank's online payment Web SDK v2 (spec 2.0.3).

- `authorize`, `confirmUrl`, `inquiry` (with `isPaid(price)`),
  `decryptCallback` / `parseCallback`.
- Payloads, hashes and callbacks reproduce the known answers in
  `spec/test-vectors`.
- Business errors are returned in `status`; transport and local failures
  throw `WingException` with a `WingErrorType` and `isRetryable`.
- `suspend` API on the JDK `HttpClient`, replaceable through
  `WingHttpClient`; injectable `Clock`, `WingCrypto`, `WingLogger` and
  `rand_str` source.
