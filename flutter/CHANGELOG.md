## 1.0.0

- First release, built on `dart_wing` 1.0.0, which it re-exports.
- `WingCheckoutView`: Wing's payment page in a web view; reports
  `WingCheckoutResult` (`success`, `failed`, `cancelled`, with Wing's
  `token`) when Wing redirects to the return or cancel URL, without loading
  them. `WingCheckoutView.open` pushes it as a page.
- `WingCheckoutResult.match` for apps that open Wing's page their own way.
- Requires Flutter 3.35 / Dart 3.9; Android, iOS and macOS
  (`webview_flutter`).
