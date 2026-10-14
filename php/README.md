# php_wing

PHP client for Wing Bank's **online payment** API (Web SDK v2). It is the PHP
twin of [`dart_wing`](../dart): both are checked against the same known
answers in [`spec/`](../spec).

```bash
composer require kechankrisna/php_wing
```

Requires PHP 8.3+ with `ext-json` and `ext-openssl`. The default HTTP client
uses `ext-curl`; you can pass any PSR-18 client instead.

| API | Method |
|---|---|
| Authorization (encrypted payload + hash), returns Wing's payment page | `authorize` |
| Payment page of a token | `confirmUrl` |
| Transaction inquiry | `inquiry` |
| Decrypt the callback Wing POSTs after a payment | `decryptCallback` / `parseCallback` |

Run it on your server: the REST API key and the password are secrets.

## Setup

```php
use PhpWing\WingMerchant;
use PhpWing\WingService;

$wing = new WingService(new WingMerchant(
    username: $_ENV['WING_USERNAME'],
    restApiKey: $_ENV['WING_REST_API_KEY'],
    password: $_ENV['WING_PASSWORD'],
    billTillNumber: $_ENV['WING_BILL_TILL_NUMBER'],
    referer: 'https://your-shop.example',  // the domain registered with Wing
    baseApiUrl: WingMerchant::UAT_URL,     // or the production URL from Wing
    sandbox: true,                         // false in production
));
```

Every other constructor argument is optional and injectable: an `HttpClient`
(`CurlHttpClient` by default, or `Psr18HttpClient` around any PSR-18 client),
a PSR-20 clock, a `WingCrypto`, a PSR-3 logger and a `rand_str` source.

## Take a payment

```php
use PhpWing\Model\Payment;

$auth = $wing->authorize(new Payment(
    orderReferenceNo: 'order-1001',
    amount: 15,                // at most 2 decimals, sent as 15.00
    returnUrl: 'https://your-shop.example/wing/return',
    cancelUrl: 'https://your-shop.example/wing/cancel',
    itemName: 'Coffee',
));

if ($auth->isSuccess()) {
    header('Location: ' . $auth->confirmUrl);
    exit;
}
```

For a mobile app, pass `integrationType: IntegrationType::MobileApp` and
`isWingAppInstalled: true` when the Wing Bank app is installed: Wing then
opens the deep link you registered with Wing instead of `returnUrl`.

## Confirm the payment

Wing redirects the payer to `returnUrl?status=success&token=...`. Then ask
Wing, and accept only an amount at least equal to your price:

```php
$inquiry = $wing->inquiry('order-1001');
if ($inquiry->isPaid(15)) {
    // deliver; show $inquiry->transaction->transactionId on the success page
}
```

### Callback

```php
$transaction = $wing->parseCallback(file_get_contents('php://input'));
if ($transaction->covers($price)) {
    // mark $transaction->orderReferenceNo as paid
}
```

`parseCallback` accepts the JSON `{"contents": "..."}`, the form
`contents=...` or the bare value, and throws a `WingException` of type
`InvalidCallback` when the contents do not decrypt with your password.

## Errors

Wing business errors (invalid REST API key, transaction not found, ...) are
returned in `$response->status` (`code` `200` is success), never thrown. A
`PhpWing\Exception\WingException` is thrown only when Wing could not be
reached or did not answer with an `errorCode`, for a password shorter than
16 bytes, and for callbacks that do not decrypt; its `type` is an
`ErrorType` and `isRetryable()` tells whether to try again. An amount Wing
would round (more than 2 decimals) throws `\InvalidArgumentException`.

## Tests

From the repository root:

```bash
composer install
composer test:unit   # offline, includes the spec/ known answers
composer analyse     # PHPStan, level max
composer cs          # coding style
```

Integration tests authorize a real 0.10 USD payment (never paid). Copy
`php/.env.example` to `php/.env`, fill in your **UAT** credentials and run
`composer test -- --group integration`. Use another file with
`WING_ENV_FILE=...`; a file with `WING_SANDBOX="0"` is skipped unless
`WING_ALLOW_PRODUCTION=true`.
