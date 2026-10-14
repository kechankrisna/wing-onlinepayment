package io.github.kechankrisna.wing.onlinepayment

import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assumptions.assumeFalse
import org.junit.jupiter.api.Assumptions.assumeTrue
import org.junit.jupiter.api.BeforeAll
import org.junit.jupiter.api.MethodOrderer
import org.junit.jupiter.api.Order
import org.junit.jupiter.api.Tag
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.TestInstance
import org.junit.jupiter.api.TestMethodOrder
import java.io.File
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * Integration tests against Wing's online payment API, run with
 * `./gradlew integrationTest`. They read partner credentials from
 * `kotlin/.env`, or the file named by `WING_ENV_FILE`, and are skipped
 * without one.
 *
 * They authorize a real payment (0.10 USD, never paid), so a file with
 * `WING_SANDBOX="0"` is refused unless `WING_ALLOW_PRODUCTION=true`.
 */
@Tag("integration")
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
@TestMethodOrder(MethodOrderer.OrderAnnotation::class)
class UatIntegrationTest {
    private val envFile = File(System.getenv("WING_ENV_FILE") ?: ".env")
    private val order = "sdk${System.currentTimeMillis()}"
    private lateinit var referer: String
    private lateinit var wing: WingService

    @BeforeAll
    fun setUp() {
        assumeTrue(envFile.isFile, "no ${envFile.path} with Wing credentials")
        val env = readEnv(envFile)
        val production = env["WING_SANDBOX"] == "0"
        assumeFalse(
            production && System.getenv("WING_ALLOW_PRODUCTION") != "true",
            "${envFile.path} sets WING_SANDBOX=\"0\"; set WING_ALLOW_PRODUCTION=true to run tests that authorize real payments",
        )
        referer = env["WING_REFERER_DOMAIN"]?.takeIf { it.isNotEmpty() } ?: "https://example.com"
        wing =
            WingService(
                WingMerchant(
                    username = env["WING_USERNAME"].orEmpty(),
                    restApiKey = env["WING_REST_API_KEY"].orEmpty(),
                    password = env["WING_PASSWORD"].orEmpty(),
                    billTillNumber = env["WING_BILL_TILL_NUMBER"].orEmpty(),
                    referer = referer,
                    baseUrl = env["WING_API_URL"]?.takeIf { it.isNotEmpty() } ?: WingMerchant.UAT_URL,
                    sandbox = !production,
                ),
                logger = { println(it) },
            )
    }

    @Test
    @Order(1)
    fun `authorize returns the payment page`() =
        runBlocking {
            val response =
                wing.authorize(
                    WingPayment(order, 0.1, "$referer/wing/return", "$referer/wing/cancel", itemName = "kotlin integration test"),
                )
            assertTrue(response.isSuccess, "${response.status}")
            assertTrue(response.confirmUrl.orEmpty().contains(WingService.CONFIRM_PATH + "?token="))
        }

    @Test
    @Order(2)
    fun `inquiry of an unpaid order is reported, not thrown`() =
        runBlocking {
            assertFalse(wing.inquiry(order).isPaid(0.1))
        }

    /** `KEY=value` lines; quotes around the value are removed, `#` lines ignored. */
    private fun readEnv(file: File): Map<String, String> =
        file
            .readLines()
            .map { it.trim() }
            .filter { it.isNotEmpty() && !it.startsWith("#") && '=' in it }
            .associate { line ->
                val key =
                    line
                        .substringBefore('=')
                        .trim()
                        .removePrefix("export ")
                        .trim()
                val value = line.substringAfter('=').trim()
                val unquoted =
                    if (value.length >= 2 && (value.first() == '"' || value.first() == '\'') && value.last() == value.first()) {
                        value.substring(1, value.length - 1)
                    } else {
                        value
                    }
                key to unquoted
            }
}
