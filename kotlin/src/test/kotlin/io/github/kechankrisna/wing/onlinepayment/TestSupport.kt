package io.github.kechankrisna.wing.onlinepayment

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.io.File
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset

/** Access to the shared spec/ folder and the fixed inputs of the known answers. */
object Spec {
    const val RAND_STR = "cbae7968ed6d0eff"
    const val TIMESTAMP = "1624684179"
    const val PASSWORD = "test-password-0123456789abcdefgh"

    private val dir = File(System.getProperty("wing.specDir") ?: "../spec")

    val knownAnswers: Map<String, String> by lazy {
        Json
            .parseToJsonElement(File(dir, "test-vectors/php_known_answers.json").readText())
            .jsonObject
            .mapValues { it.value.jsonPrimitive.content }
    }

    val clock: Clock = Clock.fixed(Instant.ofEpochSecond(TIMESTAMP.toLong()), ZoneOffset.UTC)

    fun merchant(
        password: String = PASSWORD,
        sandbox: Boolean = true,
    ): WingMerchant =
        WingMerchant(
            username = "online.testing",
            restApiKey = "test-rest-api-key",
            password = password,
            billTillNumber = "2000",
            referer = "https://shop.test",
            baseUrl = "https://wing.test/wingonlinesdkv2/",
            sandbox = sandbox,
        )

    fun builder(merchant: WingMerchant = merchant()): WingRequestBuilder = WingRequestBuilder(merchant, clock) { RAND_STR }

    val minimalPayment: WingPayment =
        WingPayment(
            orderReferenceNo = "c19245baae",
            amount = 15,
            returnUrl = "https://shop.test/wing/return?order=c19245baae",
            cancelUrl = "https://shop.test/wing/cancel?order=c19245baae",
        )

    val fullPayment: WingPayment =
        minimalPayment.copy(
            integrationType = WingIntegrationType.MOBILE_APP,
            isWingAppInstalled = true,
            itemName = "កាហ្វេ / coffee",
            merchantName = "Testing Shop",
            wingAccount = "00001614",
        )
}

/** Records requests and answers them with [reply]. */
class FakeHttpClient(
    private val reply: (url: String) -> WingHttpResponse,
) : WingHttpClient {
    data class Request(
        val url: String,
        val headers: Map<String, String>,
        val body: String,
    )

    val requests: MutableList<Request> = mutableListOf()

    override suspend fun post(
        url: String,
        headers: Map<String, String>,
        body: ByteArray,
    ): WingHttpResponse {
        requests += Request(url, headers, body.toString(Charsets.UTF_8))
        return reply(url)
    }

    companion object {
        fun json(
            body: JsonElement,
            statusCode: Int = 200,
        ): FakeHttpClient = FakeHttpClient { WingHttpResponse(statusCode, body.toString()) }

        fun json(
            body: String,
            statusCode: Int = 200,
        ): FakeHttpClient = FakeHttpClient { WingHttpResponse(statusCode, body) }

        fun failing(error: Exception): FakeHttpClient = FakeHttpClient { throw error }
    }
}
