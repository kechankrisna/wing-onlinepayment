package io.github.kechankrisna.wing.onlinepayment

import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * Payloads, hashes and callbacks must equal the known answers in
 * spec/test-vectors, computed with PHP's openssl_encrypt as in Wing's spec.
 */
class KnownAnswersTest {
    private val kat = Spec.knownAnswers

    @Test
    fun `payload with the required fields only`() {
        assertEquals(kat["payload_minimal_json"], Spec.builder().payloadJson(Spec.minimalPayment, Spec.RAND_STR, Spec.TIMESTAMP))
        assertEquals(
            listOf(
                "username" to "online.testing",
                "rest_api_key" to "test-rest-api-key",
                "payload" to kat.getValue("payload_minimal"),
                "hash" to kat.getValue("hash"),
                "sandbox" to "1",
            ),
            Spec.builder().authorization(Spec.minimalPayment).toList(),
        )
    }

    @Test
    fun `payload with every field`() {
        assertEquals(kat["payload_full_json"], Spec.builder().payloadJson(Spec.fullPayment, Spec.RAND_STR, Spec.TIMESTAMP))
        assertEquals(kat["payload_full"], Spec.builder().authorization(Spec.fullPayment)["payload"])
    }

    @Test
    fun `explicit rand_str and timestamp give the same body`() {
        val body = WingRequestBuilder(Spec.merchant()).authorization(Spec.minimalPayment, Spec.RAND_STR, Spec.TIMESTAMP)
        assertEquals(kat["payload_minimal"], body["payload"])
        assertEquals(kat["hash"], body["hash"])
    }

    @Test
    fun `hash of a KHR amount`() {
        assertEquals(kat["hash_khr"], Spec.builder().hash("12000.00", "c19245baae", Spec.RAND_STR, Spec.TIMESTAMP))
    }

    @Test
    fun `short and long passwords are padded and truncated like openssl_encrypt`() {
        val short = Spec.builder(Spec.merchant(kat.getValue("short_password"))).authorization(Spec.minimalPayment)
        assertEquals(kat["payload_minimal_short_password"], short["payload"])
        assertEquals(kat["hash_short_password"], short["hash"])
        val long = Spec.builder(Spec.merchant(kat.getValue("long_password"))).authorization(Spec.minimalPayment)
        assertEquals(kat["payload_minimal_long_password"], long["payload"])
    }

    @Test
    fun `callback contents`() {
        assertEquals(kat["callback_json"], WingService(Spec.merchant()).decryptCallback(kat.getValue("callback_contents")))
    }
}
