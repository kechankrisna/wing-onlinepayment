## 1.0.0

- First release, built on `dart_wing` 1.0.0, which it re-exports.
- `WingCheckoutView`: Wing's payment page in a web view; reports
  `WingCheckoutResult` (`success`, `failed`, `cancelled`, with Wing's
  `token`) when Wing redirects to the return or cancel URL, without loading
  them. `WingCheckoutView.open` pushes it as a page.
- `WingCheckoutResult.match` for apps that open Wing's page their own way.
- Complete example: cart, authorization behind a `PaymentBackend`, Wing's
  page, confirmation with `inquiry`, receipt; configured with a `.env`.
- `onWebViewCreated` gives the `InAppWebViewController`, e.g. to read the
  page.
- Requires Flutter 3.35 / Dart 3.9; Android, iOS, macOS, Windows and web
  (`flutter_inappwebview`). Opened Wing's staging payment page on macOS.
