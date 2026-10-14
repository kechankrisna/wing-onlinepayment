# @kechankrisna/wing-onlinepayment

Node.js client for Wing Bank's **online payment** API (Web SDK v2). It is
the TypeScript twin of [`dart_wing`](../dart) and
[`kechankrisna/php_wing`](../php): all are checked against the same known
answers in [`spec/`](../spec).

Node.js 22+, TypeScript types included, no runtime dependencies (it uses the
built-in `fetch` and `node:crypto`).

```sh
npm install @kechankrisna/wing-onlinepayment
```

| API                                                                   | Method                              |
| --------------------------------------------------------------------- | ----------------------------------- |
| Authorization (encrypted payload + hash), returns Wing's payment page | `authorize`                         |
| Payment page of a token                                               | `confirmUrl`                        |
| Transaction inquiry                                                   | `inquiry`                           |
| Decrypt the callback Wing POSTs after a payment                       | `decryptCallback` / `parseCallback` |

Run it on your server: the REST API key and the password are secrets.

## Setup

```ts
import { WingMerchant, WingService } from '@kechankrisna/wing-onlinepayment';

const wing = new WingService({
  merchant: new WingMerchant({
    username: process.env.WING_USERNAME!,
    restApiKey: process.env.WING_REST_API_KEY!,
    password: process.env.WING_PASSWORD!,
    billTillNumber: process.env.WING_BILL_TILL_NUMBER!,
    referer: 'https://your-shop.example', // the domain registered with Wing
    baseUrl: WingMerchant.UAT_URL, // or the production URL from Wing
    sandbox: true, // false in production
  }),
});
```

`WingMerchant` keeps the REST API key and password out of `toString()`,
`console.log()` / `util.inspect()` and `JSON.stringify()`.

## Take a payment

```ts
const auth = await wing.authorize({
  orderReferenceNo: 'order-1001',
  amount: 15, // at most 2 decimals, sent as 15.00
  returnUrl: 'https://your-shop.example/wing/return',
  cancelUrl: 'https://your-shop.example/wing/cancel',
  itemName: 'Coffee',
});
if (auth.isSuccess) res.redirect(auth.confirmUrl!);
```

For a mobile app, pass `integrationType: 'MOBAPP'` (or
`IntegrationType.mobileApp`) and `isWingAppInstalled: true` when the Wing
Bank app is installed.

## Confirm the payment

```ts
// Wing redirected the payer to returnUrl?status=success&token=...
const inquiry = await wing.inquiry('order-1001');
if (inquiry.isPaid(15)) {
  // deliver; show inquiry.transaction!.transactionId on the success page
}
```

### Callback

Decrypt the **raw** body:

```ts
app.post('/wing/callback', express.text({ type: '*/*' }), (req, res) => {
  const transaction = wing.parseCallback(req.body); // throws invalidCallback
  if (transaction.covers(price)) {
    // mark transaction.orderReferenceNo as paid
  }
  res.sendStatus(200);
});
```

## Errors

- Wing business errors (invalid REST API key, transaction not found, ...)
  are **returned** in `response.status` (`code` `200` is success).
- `WingError` is **thrown** when Wing could not be reached or did not answer
  with an `errorCode`, for a password shorter than 16 bytes, and for
  callbacks that do not decrypt. Branch on `error.type` (`connection`,
  `timeout`, `cancelled`, `badCertificate`, `unexpectedResponse`,
  `encryption`, `invalidCallback`, `unknown`); `error.isRetryable` tells
  whether retrying later may help.
- An amount Wing would round (more than 2 decimals) rejects with a
  `RangeError`.

## Dependency injection

```ts
new WingService({
  merchant,
  fetch: myFetch, // any fetch-compatible client
  clock: () => new Date(), // source of timestamp
  random: myRandom, // source of rand_str (16 hex characters)
  crypto: myCrypto, // implements WingCrypto
  logger: (line) => log.debug(line), // REST API key masked
  timeoutMs: 30_000, // default 60 000
});
```

## Tests

```sh
cd node
npm ci
npm run typecheck && npm run lint && npm run format:check
npm run test:unit   # offline, includes the spec/ known answers
npm run build
```

Integration tests authorize a real 0.10 USD payment (never paid). Copy
`.env.example` to `.env`, fill in your **UAT** credentials and run
`npx vitest run test/integration.test.ts`. Use another file with
`WING_ENV_FILE=...`; credentials with `WING_SANDBOX="0"` are skipped unless
`WING_ALLOW_PRODUCTION=true`.

## License

MIT
