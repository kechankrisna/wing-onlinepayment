package io.github.kechankrisna.wing.onlinepayment

import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonObject
import java.math.BigDecimal
import java.net.ConnectException
import java.net.URLEncoder
import java.net.http.HttpTimeoutException
import java.util.Base64
import javax.net.ssl.SSLHandshakeException
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** Offline tests with a fake HTTP client: requests, parsing and errors. */
class WingServiceTest {
    private fun service(http: WingHttpClient): WingService = WingService(Spec.merchant(), http, Spec.clock) { Spec.RAND_STR }

    @Test
    fun `amounts have 2 decimals`() {
        assertEquals("15.00", WingRequestBuilder.formatAmount(15))
        assertEquals("2.50", WingRequestBuilder.formatAmount(2.5))
        assertEquals("0.07", WingRequestBuilder.formatAmount(0.07))
        assertEquals("0.10", WingRequestBuilder.formatAmount(0.1f))
        assertEquals("12000.00", WingRequestBuilder.formatAmount(12000L))
        assertEquals("1234567.89", WingRequestBuilder.formatAmount(1234567.89))
        assertEquals("6.50", WingRequestBuilder.formatAmount(BigDecimal("6.500")))
    }

    @Test
    fun `amounts Wing would round, or not positive, are rejected`() {
        for (amount in listOf<Number>(1.005, 0.1 + 0.2, 0, -1, Double.NaN, 1e13, BigDecimal("1.005"))) {
            assertFailsWith<IllegalArgumentException>("$amount") { WingRequestBuilder.formatAmount(amount) }
        }
    }

    @Test
    fun `rand_str and timestamp`() {
        val values = (1..20).map { WingRequestBuilder.randomString() }.toSet()
        assertEquals(20, values.size)
        values.forEach { assertTrue(Regex("[0-9a-f]{16}").matches(it), it) }
        val payload =
            DefaultWingCrypto.aes256CbcDecrypt(
                Spec.builder().authorization(Spec.minimalPayment).getValue("payload"),
                Spec.PASSWORD,
                DefaultWingCrypto.passwordIv(Spec.PASSWORD),
            )
        assertTrue(payload.contains("\"timestamp\":\"1624684179\""), payload)
        assertFailsWith<IllegalArgumentException> { Spec.builder().authorization(Spec.minimalPayment, randStr = "XYZ") }
        assertFailsWith<IllegalArgumentException> { Spec.builder().authorization(Spec.minimalPayment, timestamp = "2026-01-02") }
    }

    @Test
    fun `production sends sandbox 0`() {
        assertEquals("0", Spec.builder(Spec.merchant(sandbox = false)).authorization(Spec.minimalPayment)["sandbox"])
        assertEquals(
            mapOf("username" to "online.testing", "rest_api_key" to "test-rest-api-key", "order_reference_no" to "x", "sandbox" to "1"),
            Spec.builder().inquiry("x"),
        )
    }

    @Test
    fun `authorize posts JSON with a Base64 Referer`() =
        runBlocking {
            val token = "eyJhbGciOiJIUzI1NiJ9.e30.sig"
            val http =
                FakeHttpClient.json(
                    buildJsonObject {
                        put("errorCode", "200")
                        put("errorText", "Success authorization")
                        put("token", token)
                    },
                )

            val response = service(http).authorize(Spec.minimalPayment)

            assertTrue(response.isSuccess)
            assertEquals(
                "https://wing.test/wingonlinesdkv2/v1/online/payment/confirm?token=" +
                    URLEncoder.encode(Base64.getEncoder().encodeToString(token.toByteArray()), Charsets.UTF_8),
                response.confirmUrl,
            )
            val request = http.requests.single()
            assertEquals("https://wing.test/wingonlinesdkv2" + WingService.AUTHORIZATION_PATH, request.url)
            assertEquals("application/json", request.headers["Content-Type"])
            assertEquals(Base64.getEncoder().encodeToString("https://shop.test".toByteArray()), request.headers["Referer"])
            assertEquals("kotlin-wing/${WingService.SDK_VERSION}", request.headers["User-Agent"])
            assertEquals(
                Spec.builder().authorization(Spec.minimalPayment),
                Json.parseToJsonElement(request.body).jsonObject.mapValues { it.value.jsonPrimitive.content },
            )
        }

    @Test
    fun `confirm URL percent-encodes the token`() {
        // base64 of these bytes holds '+', '/' and '='
        val url = WingService(Spec.merchant()).confirmUrl(String(charArrayOf('û', 'ÿ')))
        val token = url.substringAfter("?token=")
        assertFalse(token.contains('+') || token.contains('/') || token.contains('='), token)
    }

    @Test
    fun `a Wing error is returned, not thrown, whatever the HTTP status`() =
        runBlocking {
            val response =
                service(
                    FakeHttpClient.json(
                        buildJsonObject {
                            put("errorCode", "401")
                            put("errorText", "Invalid rest api key.")
                            put("token", JsonNull)
                        },
                        401,
                    ),
                ).authorize(Spec.minimalPayment)
            assertFalse(response.isSuccess)
            assertEquals("401", response.status.code)
            assertNull(response.confirmUrl)
        }

    @Test
    fun `a password shorter than 16 bytes is an encryption error`() {
        val error =
            assertFailsWith<WingException> {
                runBlocking { WingService(Spec.merchant("too-short")).authorize(Spec.minimalPayment) }
            }
        assertEquals(WingErrorType.ENCRYPTION, error.type)
    }

    @Test
    fun `inquiry at the top level`() =
        runBlocking {
            val http =
                FakeHttpClient.json(
                    """{"errorCode":"200","respType":"respType","amount":"15.00","total_amount":15.0,"currency":"USD",""" +
                        """"order_reference_no":"c19245baae","transaction_id":"0002355252200023"}""",
                )

            val response = service(http).inquiry("c19245baae")

            assertTrue(response.isSuccess)
            assertEquals(15.0, response.transaction?.amount)
            assertEquals(
                "respType",
                response.transaction
                    ?.raw
                    ?.get("respType")
                    ?.jsonPrimitive
                    ?.content,
            )
            assertTrue(response.isPaid(15))
            assertFalse(response.isPaid(15.01))
            assertEquals("https://wing.test/wingonlinesdkv2" + WingService.INQUIRY_PATH, http.requests.single().url)
        }

    @Test
    fun `inquiry inside data`() =
        runBlocking {
            val response =
                service(
                    FakeHttpClient.json(
                        buildJsonObject {
                            put("errorCode", "200")
                            putJsonObject("data") {
                                put("amount", 2.5)
                                put("transaction_id", "T1")
                            }
                        },
                    ),
                ).inquiry("x")
            assertEquals("T1", response.transaction?.transactionId)
            assertTrue(response.isPaid(2.5))
        }

    @Test
    fun `transaction not found is returned`() =
        runBlocking {
            val response = service(FakeHttpClient.json("""{"errorCode":"006035","errorText":"Transaction not found...!"}""")).inquiry("x")
            assertFalse(response.isSuccess)
            assertEquals("006035", response.status.code)
            assertNull(response.transaction)
            assertFalse(response.isPaid(1))
        }

    @Test
    fun `an HTML page or JSON without errorCode is an unexpected response`() {
        for (body in listOf("<html>", """{"status":"ok"}""")) {
            val error = assertFailsWith<WingException> { runBlocking { service(FakeHttpClient.json(body, 502)).inquiry("x") } }
            assertEquals(WingErrorType.UNEXPECTED_RESPONSE, error.type)
            assertEquals(502, error.statusCode)
            assertTrue(error.isRetryable)
        }
    }

    @Test
    fun `transport failures are mapped to error types`() {
        val cases =
            listOf(
                ConnectException("refused") to WingErrorType.CONNECTION,
                HttpTimeoutException("slow") to WingErrorType.TIMEOUT,
                SSLHandshakeException("bad cert").apply { initCause(java.security.cert.CertificateException("x")) } to
                    WingErrorType.BAD_CERTIFICATE,
                IllegalStateException("boom") to WingErrorType.UNKNOWN,
            )
        for ((cause, type) in cases) {
            val error = assertFailsWith<WingException> { runBlocking { service(FakeHttpClient.failing(cause)).inquiry("x") } }
            assertEquals(type, error.type, "$cause")
        }
    }

    @Test
    fun `callback bodies parse`() {
        val contents = Spec.knownAnswers.getValue("callback_contents")
        val wing = WingService(Spec.merchant())
        for (body in listOf("""{"contents":"$contents"}""", "contents=" + URLEncoder.encode(contents, Charsets.UTF_8), contents)) {
            val callback = wing.parseCallback(body)
            assertEquals("0002355252200023", callback.transactionId)
            assertEquals("1234321", callback.orderReferenceNo)
            assertEquals(1.5, callback.amount)
            assertEquals("USD", callback.currency)
            assertEquals(" ONL015627", callback.psTrnId)
            assertTrue(callback.covers(1.5))
            assertFalse(callback.covers(1.51))
        }
    }

    @Test
    fun `callbacks from another password are rejected`() {
        val other = WingService(Spec.merchant("another-password-0123456789"))
        for (contents in listOf(
            Spec.knownAnswers.getValue("callback_contents"),
            "not base64!",
            Base64.getEncoder().encodeToString("short".toByteArray()),
        )) {
            val error = assertFailsWith<WingException> { other.parseCallback(contents) }
            assertEquals(WingErrorType.INVALID_CALLBACK, error.type)
        }
        val list = DefaultWingCrypto.aes256CbcEncrypt("[1]", Spec.PASSWORD, DefaultWingCrypto.passwordIv(Spec.PASSWORD))
        assertEquals(
            WingErrorType.INVALID_CALLBACK,
            assertFailsWith<WingException> { WingService(Spec.merchant()).parseCallback(list) }.type,
        )
    }

    @Test
    fun `numbers sent as strings parse`() {
        val transaction = WingTransaction.from(Json.parseToJsonElement("""{"amount":"10.5","fee":0,"transaction_id":123}""").jsonObject)
        assertEquals(10.5, transaction.amount)
        assertEquals(0.0, transaction.fee)
        assertEquals("123", transaction.transactionId)
    }

    @Test
    fun `secrets never appear in toString or logs`() =
        runBlocking {
            val text = Spec.merchant().toString()
            assertFalse(text.contains("test-rest-api-key") || text.contains("test-password"), text)
            val lines = mutableListOf<String>()
            WingService(
                Spec.merchant(),
                FakeHttpClient.json("""{"errorCode":"006035","errorText":"x"}"""),
                logger = { lines += it },
            ).inquiry("x")
            assertEquals(2, lines.size)
            assertFalse(lines.joinToString().contains("test-rest-api-key"))
        }

    @Test
    fun `version matches the Gradle version`() {
        assertEquals(System.getProperty("wing.version"), WingService.SDK_VERSION)
    }
}
