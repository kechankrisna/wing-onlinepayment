# dart_wing

Dart client for Wing Bank's **online payment** API (Web SDK v2): take
payments on Wing's hosted payment page, from a website or, with a deep link
back, from your app.

| API | Method |
|---|---|
| Authorization (encrypted payload + hash), returns Wing's payment page | `authorize` |
| Payment page of a token | `confirmUrl` |
| Transaction inquiry | `inquiry` |
| Decrypt the callback Wing POSTs after a payment | `decryptCallback` / `parseCallback` |

## Setup

```dart
import 'package:dart_wing/dart_wing.dart';

final wing = WingService(
  merchant: WingMerchant(
    username: 'online.yourshop',
    restApiKey: 'your REST API key',
    password: 'your encryption password',
    billTillNumber: 'your biller code or till number',
    referer: 'https://your-registered-domain.com', // sent Base64-encoded
    baseApiUrl: WingMerchant.uatBaseUrl, // or the production URL from Wing
    sandbox: true, // false in production
  ),
);
```

Call Wing from **your server**: the REST API key and the password are
secrets.

## Take a payment

```dart
final auth = await wing.authorize(const WingPayment(
  orderReferenceNo: 'order-1001', // unique
  amount: 15, // at most 2 decimals, sent as 15.00
  returnUrl: 'https://your-domain.com/wing/return',
  cancelUrl: 'https://your-domain.com/wing/cancel',
  itemName: 'Coffee',
));
if (auth.isSuccess) {
  // redirect the payer to auth.confirmUrl, or open it in a web view
}
```

For a mobile app, pass `integrationType: WingIntegrationType.mobileApp` and
`isWingAppInstalled: true` when the Wing Bank app is installed: Wing then
opens the deep link you registered with Wing instead of `returnUrl`.

`rand_str` and `timestamp` are generated, the payload is encrypted and the
hash computed by the SDK.

## Confirm the payment

Wing redirects the payer to `returnUrl?status=success&token=...`. Then ask
Wing, and accept only an amount at least equal to your price:

```dart
final inquiry = await wing.inquiry(orderReferenceNo: 'order-1001');
if (inquiry.isPaid(15)) {
  // deliver; show inquiry.transaction!.transactionId on the success page
}
```

### Callback

If Wing pushes payments to your callback URL, decrypt the raw body (JSON
`{"contents": "..."}`, form `contents=...`, or the bare value):

```dart
final transaction = wing.parseCallback(rawBody); // throws invalidCallback
if (transaction.covers(price)) {
  // mark transaction.orderReferenceNo as paid
}
```

## Errors

- Wing business errors (invalid REST API key, transaction not found, ...)
  are **returned** in `response.status`; check `response.isSuccess` and
  `response.status.code` (`200` is success).
- `WingException` is **thrown** when Wing could not be reached or did not
  answer with an `errorCode`, for a password shorter than 16 bytes, and for
  callbacks that do not decrypt. Branch on `type` (`connection`, `timeout`,
  `cancelled`, `badCertificate`, `unexpectedResponse`, `encryption`,
  `invalidCallback`, `unknown`); `isRetryable` tells whether retrying later
  may help.
- `authorize` throws an `ArgumentError` for an amount Wing would round
  (more than 2 decimals) or that is not positive.

Every call accepts a `CancelToken` (re-exported from `dio`).

## Dependency injection

```dart
final wing = WingService(
  merchant: merchant,
  dio: myDio,                  // your HTTP client, used as is and reused
  clock: () => DateTime.now(), // source of timestamp
  random: myRandom,            // source of rand_str (16 hex characters)
  crypto: myCrypto,            // AES-256-CBC and SHA-256
  logger: (line) => log(line), // REST API key masked; nothing logged without it
);
```

## Tests

```sh
dart test -x integration
dart test -t integration
WING_ENV_FILE=.env.production dart test -t integration
```

The first runs the offline tests. Their expected payloads, hashes and
callbacks are computed with PHP's `openssl_encrypt`, as in Wing's spec
(`spec/test-vectors/php_known_answers.php` at the repository root).

The others call Wing with the credentials in `.env` (copy `.env.example`)
or in the file named by `WING_ENV_FILE`. They authorize a 0.10 USD payment
(never paid), so a file with `WING_SANDBOX="0"` is refused unless you also
set `WING_ALLOW_PRODUCTION=true`.

See the `example` folder for a Flutter demo.
