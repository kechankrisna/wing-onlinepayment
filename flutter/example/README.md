# flutter_wing_checkout example

A complete Wing checkout: a cart, **Pay with Wing**, Wing's payment page in
`WingCheckoutView`, confirmation with the inquiry API, and a receipt with
Wing's transaction id.

```
Cart ─▶ authorize ─▶ Wing's page ─▶ redirect ─▶ inquiry ─▶ receipt
        (server)     (web view)    success?    amount ≥ price?
```

## Run it

1. Copy `.env.example` to `.env` and fill in your Wing UAT credentials.
   `.env` is git-ignored: never commit it.
2. Create the platform folders once (they are git-ignored):

   ```sh
   flutter create --platforms android,ios,macos .
   ```

   On macOS, add the network client entitlement to
   `macos/Runner/DebugProfile.entitlements` and
   `macos/Runner/Release.entitlements`:

   ```xml
   <key>com.apple.security.network.client</key>
   <true/>
   ```

3. Run with the `.env`:

   ```sh
   flutter run --dart-define-from-file=.env
   ```

Without a `.env`, the app shows these instructions instead.

## Your server, not the app

> **Demo only.** `DemoPaymentBackend` calls Wing from the app with the
> `.env` secrets compiled in. A real app must not contain the REST API key
> or password.

The app talks to a `PaymentBackend` (`lib/src/payment_backend.dart`):

| Method | Your server does |
|---|---|
| `createCheckout(amount, itemName)` | stores the order, calls `WingService.authorize`, returns `confirmUrl`, `returnUrl`, `cancelUrl` |
| `confirm(session)` | calls `WingService.inquiry` and checks `isPaid(price)` against the stored order |

Replace `DemoPaymentBackend` with HTTP calls to your server (which uses
`dart_wing`, `php_wing`, the Kotlin or the Node.js SDK).

A `status=success` redirect is not a proof of payment: the app always
confirms with `inquiry` and accepts only an amount at least equal to the
price, as Wing requires.

## Tests

```sh
flutter test                                                      # offline, fake backend
flutter test integration_test -d macos --dart-define-from-file=.env  # live, Wing UAT
```

The offline tests cover every outcome: paid, cancelled (then checked
later), failed, an amount below the price, and an authorization error. The
live tests authorize real payments and open Wing's real payment page.
