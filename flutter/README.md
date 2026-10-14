# flutter_wing

Flutter checkout for Wing Bank online payment, built on
[`dart_wing`](https://pub.dev/packages/dart_wing), which it re-exports.

```yaml
dependencies:
  flutter_wing: ^1.0.0
```

## Paying in a web view

Authorize the payment on **your server**, not in the app: the Wing REST API
key and password are secrets and must not ship inside an app. Your server
calls `authorize` with `dart_wing` (or the PHP, Kotlin or Node.js SDK) and
returns `confirmUrl` to the app, which opens Wing's payment page:

```dart
import 'package:flutter_wing/flutter_wing.dart';

final result = await WingCheckoutView.open(
  context,
  confirmUrl: confirmUrl, // from your server
  returnUrl: 'https://your-domain.com/wing/return', // as authorized
  cancelUrl: 'https://your-domain.com/wing/cancel',
);
switch (result?.status) {
  case WingCheckoutStatus.success:
    // ask your server to confirm with WingService.inquiry and the price
  case WingCheckoutStatus.failed:
  case WingCheckoutStatus.cancelled:
  case null: // back button
}
```

`WingCheckoutView` stops at the return or cancel URL without loading it. Use
the widget directly to embed it in your own page, or
`WingCheckoutResult.match` if you open Wing's page another way.

A redirect with `status=success` is not a proof of payment: confirm on your
server with `inquiry` (or the callback) before delivering.

Platforms: Android, iOS and macOS, as supported by
[`webview_flutter`](https://pub.dev/packages/webview_flutter).

## Paying in the Wing Bank app

For `WingIntegrationType.mobileApp` payments, Wing opens the deep link you
registered with Wing after payment. Handle that link with your app's deep
link setup (for example `app_links`), then confirm on your server.
