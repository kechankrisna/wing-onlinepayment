package io.github.kechankrisna.wing.onlinepayment

import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import java.net.URLDecoder
import java.net.URLEncoder
import java.time.Clock
import java.util.Base64
import kotlin.coroutines.cancellation.CancellationException

/** Receives the SDK's request/response log lines (the REST API key is masked). */
public fun interface WingLogger {
    public fun log(message: String)
}

/**
 * Wing Bank online payment (Web SDK v2) client.
 *
 * ```kotlin
 * val wing = WingService(merchant)
 * val auth = wing.authorize(payment)
 * if (auth.isSuccess) redirect(auth.confirmUrl!!)
 * // later, after Wing redirects to your return_url:
 * if (wing.inquiry("order-1001").isPaid(15)) deliverOrder()
 * ```
 *
 * Wing business errors (invalid REST API key, transaction not found, ...)
 * are returned in `status`. A [WingException] is thrown only when Wing could
 * not be reached or did not answer with an `errorCode`.
 *
 * Run it on your server (Ktor, Spring, ...): the REST API key and the
 * password are secrets and must never ship in an Android app.
 *
 * @param merchant partner credentials used to encrypt and sign
 * @param httpClient HTTP stack (default: [JdkWingHttpClient], created on first call)
 * @param clock source of `timestamp`
 * @param crypto AES-256-CBC and SHA-256
 * @param logger receives request/response logs; nothing is logged without it
 * @param random source of `rand_str`
 */
public class WingService(
    public val merchant: WingMerchant,
    httpClient: WingHttpClient? = null,
    clock: Clock = Clock.systemUTC(),
    public val crypto: WingCrypto = DefaultWingCrypto,
    private val logger: WingLogger? = null,
    random: () -> String = WingRequestBuilder::randomString,
) {
    /** Builds the request bodies; exposed to support new endpoints. */
    public val requestBuilder: WingRequestBuilder = WingRequestBuilder(merchant, clock, crypto, random)

    // created on first use, so decrypting a callback starts no HTTP client
    private val http: WingHttpClient by lazy { httpClient ?: JdkWingHttpClient() }

    /**
     * Encrypts and signs [payment] and asks Wing for a payment token. On
     * success, redirect the payer to [WingAuthorizationResponse.confirmUrl].
     *
     * @throws IllegalArgumentException for an amount with more than 2 decimals
     * @throws WingException of type [WingErrorType.ENCRYPTION] for a password
     *   shorter than 16 bytes
     */
    public suspend fun authorize(payment: WingPayment): WingAuthorizationResponse {
        if (merchant.password.toByteArray(Charsets.UTF_8).size < PASSWORD_IV_BYTES) {
            throw WingException(WingErrorType.ENCRYPTION, "The Wing password must be at least 16 bytes: its first 16 are the IV")
        }
        val body = requestBuilder.authorization(payment)
        return post(AUTHORIZATION_PATH, body) { json ->
            val token = (json["token"] as? JsonPrimitive)?.takeIf { it.isString }?.content
            WingAuthorizationResponse(
                WingStatus.from(json),
                token,
                token?.takeIf { it.isNotEmpty() }?.let(::confirmUrl),
            )
        }
    }

    /** Wing's payment page for an authorization [token]: `{base}/v1/online/payment/confirm?token=base64(token)`. */
    public fun confirmUrl(token: String): String =
        url(CONFIRM_PATH) + "?token=" +
            URLEncoder.encode(Base64.getEncoder().encodeToString(token.toByteArray(Charsets.UTF_8)), Charsets.UTF_8)

    /**
     * Details of the payment of [orderReferenceNo]. Call it when Wing
     * redirects to your `return_url` with `status=success`, and check
     * [WingInquiryResponse.isPaid] with your price before delivering.
     */
    public suspend fun inquiry(orderReferenceNo: String): WingInquiryResponse =
        post(INQUIRY_PATH, requestBuilder.inquiry(orderReferenceNo), WingInquiryResponse::from)

    /**
     * The JSON in the `contents` Wing POSTs to your callback URL, decrypted
     * with the merchant password.
     *
     * @throws WingException of type [WingErrorType.INVALID_CALLBACK] when it
     *   was not encrypted with the password
     */
    public fun decryptCallback(contents: String): String =
        try {
            crypto.aes256CbcDecrypt(contents, merchant.password, DefaultWingCrypto.passwordIv(merchant.password))
        } catch (e: IllegalArgumentException) {
            throw WingException(
                WingErrorType.INVALID_CALLBACK,
                "Callback contents could not be decrypted with the Wing password",
                cause = e,
            )
        }

    /**
     * Decrypts and parses the body Wing POSTed to your callback URL: the JSON
     * `{"contents": "..."}`, the form `contents=...`, or the value itself.
     * Still confirm with [inquiry] and the amount before delivering.
     *
     * @throws WingException of type [WingErrorType.INVALID_CALLBACK]
     */
    public fun parseCallback(body: String): WingTransaction {
        val decrypted = decryptCallback(callbackContents(body))
        val decoded =
            try {
                Json.parseToJsonElement(decrypted)
            } catch (e: IllegalArgumentException) {
                throw WingException(WingErrorType.INVALID_CALLBACK, "Decrypted callback is not JSON", cause = e)
            }
        if (decoded !is JsonObject) {
            throw WingException(WingErrorType.INVALID_CALLBACK, "Decrypted callback is not a JSON object")
        }
        return WingTransaction.from(decoded)
    }

    /**
     * POSTs JSON and parses Wing's reply. Wing answers errors with a JSON body
     * carrying `errorCode`, possibly with a non-2xx HTTP status, which is
     * parsed like a success.
     */
    private suspend fun <T> post(
        path: String,
        body: Map<String, String>,
        parse: (JsonObject) -> T,
    ): T {
        val url = url(path)
        val json = JsonObject(body.mapValues { JsonPrimitive(it.value) }).encode()
        logger?.log(
            "[Wing] POST $url " +
                JsonObject(body.mapValues { (key, value) -> JsonPrimitive(if (key == "rest_api_key") "***" else value) }).encode(),
        )
        val headers =
            buildMap {
                put("Accept", "application/json")
                put("Content-Type", "application/json")
                put("User-Agent", USER_AGENT)
                if (merchant.referer.isNotEmpty()) {
                    put("Referer", Base64.getEncoder().encodeToString(merchant.referer.toByteArray(Charsets.UTF_8)))
                }
            }

        val response =
            try {
                http.post(url, headers, json.toByteArray(Charsets.UTF_8))
            } catch (e: CancellationException) {
                // the caller's coroutine was cancelled: let it propagate
                currentCoroutineContext().ensureActive()
                throw transportException(e).also { logger?.log("[Wing] failed ${it.message}") }
            } catch (e: Exception) {
                throw transportException(e).also { logger?.log("[Wing] failed ${it.message}") }
            }

        logger?.log("[Wing] ${response.statusCode} ${response.body}")
        val decoded = decodeObject(response.body)
        if (decoded != null && "errorCode" in decoded) return parse(decoded)
        throw WingException(WingErrorType.UNEXPECTED_RESPONSE, "Unexpected response from Wing", response.statusCode)
    }

    private fun url(path: String): String = merchant.baseUrl.trimEnd('/') + path

    public companion object {
        /** version of this SDK */
        public const val SDK_VERSION: String = "1.0.0"

        /** sent with every request */
        public const val USER_AGENT: String = "kotlin-wing/$SDK_VERSION"

        /** endpoint of [authorize] */
        public const val AUTHORIZATION_PATH: String = "/v1/online/payment/authorization"

        /** Wing's payment page, opened by [confirmUrl] */
        public const val CONFIRM_PATH: String = "/v1/online/payment/confirm"

        /** endpoint of [inquiry]; section 4.1 of the spec (v2.0.3) gives `v2`, its endpoint list `v1` */
        public const val INQUIRY_PATH: String = "/v2/online/payment/transaction/inquiry"

        private const val PASSWORD_IV_BYTES = 16

        /** The encrypted `contents` of a callback body (see [parseCallback]). */
        public fun callbackContents(body: String): String {
            val trimmed = body.trim()
            if (trimmed.startsWith("{")) {
                val contents = decodeObject(trimmed)?.get("contents") as? JsonPrimitive
                if (contents != null && contents.isString) return contents.content
            }
            if (trimmed.startsWith("contents=")) {
                val value = trimmed.removePrefix("contents=").substringBefore('&')
                return URLDecoder.decode(value, Charsets.UTF_8)
            }
            return trimmed
        }
    }
}
