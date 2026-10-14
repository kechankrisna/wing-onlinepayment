# wing-onlinepayment (Kotlin/JVM)

Kotlin/JVM client for Wing Bank's **online payment** API (Web SDK v2). It is
the Kotlin twin of [`dart_wing`](../dart) and [`php_wing`](../php): all are
checked against the same known answers in [`spec/`](../spec).

```kotlin
// build.gradle.kts
dependencies {
    implementation("io.github.kechankrisna:wing-onlinepayment:1.0.0")
}
```

Requires JDK 17+. Dependencies: `kotlinx-coroutines-core` and
`kotlinx-serialization-json`. The default HTTP client is the JDK's
`java.net.http.HttpClient`.

> **Server-side only.** Use it from your backend (Ktor, Spring, Micronaut,
> ...). The REST API key and the password must never ship in an Android app.

| API | Method |
|---|---|
| Authorization (encrypted payload + hash), returns Wing's payment page | `authorize` |
| Payment page of a token | `confirmUrl` |
| Transaction inquiry | `inquiry` |
| Decrypt the callback Wing POSTs after a payment | `decryptCallback` / `parseCallback` |

API calls are `suspend` functions.

## Setup

```kotlin
import io.github.kechankrisna.wing.onlinepayment.WingMerchant
import io.github.kechankrisna.wing.onlinepayment.WingService

val wing = WingService(
    WingMerchant(
        username = System.getenv("WING_USERNAME"),
        restApiKey = System.getenv("WING_REST_API_KEY"),
        password = System.getenv("WING_PASSWORD"),
        billTillNumber = System.getenv("WING_BILL_TILL_NUMBER"),
        referer = "https://your-shop.example", // the domain registered with Wing
        baseUrl = WingMerchant.UAT_URL,        // or the production URL from Wing
        sandbox = true,                        // false in production
    ),
)
```

Every other constructor argument is optional and injectable: a
`WingHttpClient` (`JdkWingHttpClient` by default; implement the one-method
interface to use OkHttp, a Ktor client or a test fake), a `java.time.Clock`,
a `WingCrypto`, a `WingLogger` and a `rand_str` source.
`WingMerchant.toString()` never shows the secrets.

## Take a payment

```kotlin
val auth = wing.authorize(
    WingPayment(
        orderReferenceNo = "order-1001",
        amount = 15, // at most 2 decimals, sent as 15.00
        returnUrl = "https://your-shop.example/wing/return",
        cancelUrl = "https://your-shop.example/wing/cancel",
        itemName = "Coffee",
    ),
)
if (auth.isSuccess) call.respondRedirect(auth.confirmUrl!!)
```

For a mobile app, pass `integrationType = WingIntegrationType.MOBILE_APP` and
`isWingAppInstalled = true` when the Wing Bank app is installed.

## Confirm the payment

```kotlin
// Wing redirected the payer to returnUrl?status=success&token=...
val inquiry = wing.inquiry("order-1001")
if (inquiry.isPaid(15)) {
    // deliver; show inquiry.transaction!!.transactionId on the success page
}
```

### Callback

```kotlin
post("/wing/callback") {
    val transaction = wing.parseCallback(call.receiveText()) // throws INVALID_CALLBACK
    if (transaction.covers(price)) { /* mark transaction.orderReferenceNo as paid */ }
    call.respond(HttpStatusCode.OK)
}
```

## Errors

Wing business errors (invalid REST API key, transaction not found, ...) are
returned in `response.status` (`code` `200` is success), never thrown. A
`WingException` is thrown only when Wing could not be reached or did not
answer with an `errorCode`, for a password shorter than 16 bytes, and for
callbacks that do not decrypt. Its `type` is a `WingErrorType` and
`isRetryable` tells whether to try again. An amount Wing would round (more
than 2 decimals) throws `IllegalArgumentException`.

## Tests

```bash
cd kotlin
./gradlew build            # compile (warnings are errors), ktlint, offline tests
./gradlew ktlintFormat     # fix formatting
./gradlew integrationTest  # UAT tests, need kotlin/.env
```

Integration tests authorize a real 0.10 USD payment (never paid). Copy
`kotlin/.env.example` to `kotlin/.env` and fill in your **UAT** credentials.
Use another file with `WING_ENV_FILE=...`; a file with `WING_SANDBOX="0"` is
skipped unless `WING_ALLOW_PRODUCTION=true`.

See [CHANGELOG.md](CHANGELOG.md). MIT licensed.
