package io.github.kechankrisna.wing.onlinepayment

import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import java.math.BigDecimal
import java.math.BigInteger
import java.security.SecureRandom
import java.time.Clock
import java.util.Base64

/**
 * Builds the encrypted and hashed request bodies of the Wing online payment
 * APIs:
 *
 * - `payload` is `AES-256-CBC(JSON, password, first 16 bytes of password)`
 * - `hash` is `UPPERCASE(SHA256(AES-256-CBC(base64(username#rest_api_key#
 *   bill_till_number#amount#order_reference_no#rand_str#timestamp), password, rand_str)))`
 *
 * with AES output in base64, as PHP's `openssl_encrypt` returns it.
 *
 * @param clock source of `timestamp`
 * @param random source of `rand_str` (16 characters among `0-9` and `a-f`)
 */
public class WingRequestBuilder(
    private val merchant: WingMerchant,
    private val clock: Clock = Clock.systemUTC(),
    private val crypto: WingCrypto = DefaultWingCrypto,
    private val random: () -> String = ::randomString,
) {
    /**
     * Body of the authorization API: `username`, `rest_api_key`, `payload`,
     * `hash` and `sandbox`, in that order.
     *
     * @throws IllegalArgumentException for an amount with more than 2
     *   decimals, a malformed [randStr] or [timestamp], or a password shorter
     *   than 16 bytes
     */
    public fun authorization(
        payment: WingPayment,
        randStr: String? = null,
        timestamp: String? = null,
    ): Map<String, String> {
        val rand = randStr(randStr)
        val time = timestamp(timestamp)
        return linkedMapOf(
            "username" to merchant.username,
            "rest_api_key" to merchant.restApiKey,
            "payload" to
                crypto.aes256CbcEncrypt(
                    payloadJson(payment, rand, time),
                    merchant.password,
                    DefaultWingCrypto.passwordIv(merchant.password),
                ),
            "hash" to hash(formatAmount(payment.amount), payment.orderReferenceNo, rand, time),
            "sandbox" to sandbox,
        )
    }

    /** The JSON encrypted into `payload`, in the order of the spec's sample; absent optional fields are left out. */
    public fun payloadJson(
        payment: WingPayment,
        randStr: String,
        timestamp: String,
    ): String {
        val fields =
            linkedMapOf(
                "amount" to formatAmount(payment.amount),
                "bill_till_number" to merchant.billTillNumber,
                "order_reference_no" to payment.orderReferenceNo,
                "return_url" to payment.returnUrl,
                "cancel_url" to payment.cancelUrl,
                "rand_str" to randStr,
                "timestamp" to timestamp,
                "wing_account" to payment.wingAccount,
                "integration_type" to payment.integrationType.value,
                "is_wingapp_installed" to if (payment.isWingAppInstalled) "1" else "0",
                "item_name" to payment.itemName,
                "merchant_name" to payment.merchantName,
            )
        val present = LinkedHashMap<String, JsonPrimitive>()
        for ((key, value) in fields) if (value != null) present[key] = JsonPrimitive(value)
        return JsonObject(present).encode()
    }

    /** `hash` of an authorization; [amount] as formatted by [formatAmount]. */
    public fun hash(
        amount: String,
        orderReferenceNo: String,
        randStr: String,
        timestamp: String,
    ): String {
        val plain =
            listOf(
                merchant.username,
                merchant.restApiKey,
                merchant.billTillNumber,
                amount,
                orderReferenceNo,
                randStr,
                timestamp,
            ).joinToString("#")
        val encoded = Base64.getEncoder().encodeToString(plain.toByteArray(Charsets.UTF_8))
        val iv = randStr(randStr).toByteArray(Charsets.UTF_8)
        return crypto.sha256Upper(crypto.aes256CbcEncrypt(encoded, merchant.password, iv))
    }

    /** Body of the transaction inquiry API. */
    public fun inquiry(orderReferenceNo: String): Map<String, String> =
        linkedMapOf(
            "username" to merchant.username,
            "rest_api_key" to merchant.restApiKey,
            "order_reference_no" to orderReferenceNo,
            "sandbox" to sandbox,
        )

    private val sandbox: String get() = if (merchant.sandbox) "1" else "0"

    private fun randStr(randStr: String?): String {
        val value = randStr ?: random()
        require(RAND_STR.matches(value)) { "rand_str must be 16 characters among 0-9 and a-f, got \"$value\"" }
        return value
    }

    private fun timestamp(timestamp: String?): String {
        val value = timestamp ?: clock.instant().epochSecond.toString()
        require(DIGITS.matches(value)) { "timestamp must be Unix seconds, got \"$value\"" }
        return value
    }

    public companion object {
        private val RAND_STR = Regex("[0-9a-f]{16}")
        private val DIGITS = Regex("\\d+")
        private val MAX_AMOUNT = BigDecimal("1e13")
        private val secureRandom = SecureRandom()

        /** 16 random characters among `0-9` and `a-f`, from a secure source. */
        public fun randomString(): String = ByteArray(8).also(secureRandom::nextBytes).joinToString("") { "%02x".format(it) }

        /**
         * [amount] with 2 decimals, as Wing requires (`5.00`, `2.50`, `12000.00`).
         *
         * @throws IllegalArgumentException when it is not positive or has more
         *   than 2 decimals: Wing would charge a rounded amount
         */
        public fun formatAmount(amount: Number): String {
            val decimal =
                when (amount) {
                    is BigDecimal -> {
                        amount
                    }

                    is BigInteger -> {
                        amount.toBigDecimal()
                    }

                    is Byte, is Short, is Int, is Long -> {
                        BigDecimal.valueOf(amount.toLong())
                    }

                    else -> {
                        val double = amount.toDecimalDouble()
                        require(double.isFinite()) { "amount must be finite, got $amount" }
                        val cents = Math.round(double * 100)
                        require(cents / 100.0 == double) { "amount must have at most 2 decimals, got $amount" }
                        BigDecimal.valueOf(cents, 2)
                    }
                }
            require(decimal.signum() > 0 && decimal < MAX_AMOUNT) { "amount must be positive and below 1e13, got $amount" }
            require(decimal.stripTrailingZeros().scale() <= 2) { "amount must have at most 2 decimals, got $amount" }
            return decimal.setScale(2).toPlainString()
        }
    }
}
