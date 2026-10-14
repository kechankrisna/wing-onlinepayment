package io.github.kechankrisna.wing.onlinepayment

import kotlinx.serialization.json.JsonObject

/**
 * `errorCode` and `errorText` of Wing responses. Success is `200`.
 *
 * @property code Wing's code, e.g. `200`, `401` (invalid REST API key),
 *   `006035` (transaction not found)
 * @property message human readable message
 */
public data class WingStatus(
    public val code: String,
    public val message: String,
) {
    /** Whether Wing answered `200`. */
    public val isSuccess: Boolean get() = code == "200"

    public companion object {
        /** Parses Wing JSON. */
        public fun from(json: JsonObject): WingStatus = WingStatus(json.string("errorCode"), json.string("errorText"))
    }
}

/**
 * A Wing payment, as returned by the inquiry API and pushed to your callback
 * URL. Wing asks partners to accept only payments whose [amount] is at least
 * the price: check [covers] before delivering.
 *
 * @property amount amount the partner requested
 * @property orderReferenceNo your `order_reference_no`
 * @property transactionId Wing transaction id; show it on your success page
 * @property totalAmount total amount, which can include a fee or an exchange rate
 * @property raw every field Wing sent, including ones this class does not model
 */
public data class WingTransaction(
    public val amount: Double,
    public val orderReferenceNo: String,
    public val transactionId: String,
    public val totalAmount: Double? = null,
    public val currency: String? = null,
    public val remark: String? = null,
    public val customerName: String? = null,
    public val fee: Double? = null,
    public val feeCurrency: String? = null,
    public val wingAccount: String? = null,
    public val psTrnId: String? = null,
    public val fcTrnId: String? = null,
    public val billerName: String? = null,
    public val transactionDate: String? = null,
    public val raw: JsonObject = JsonObject(emptyMap()),
) {
    /** Whether [amount] is at least [price], compared in cents. */
    public fun covers(price: Number): Boolean = Math.round(amount * 100) >= Math.round(price.toDecimalDouble() * 100)

    public companion object {
        /** Parses Wing JSON. */
        public fun from(json: JsonObject): WingTransaction =
            WingTransaction(
                amount = json.double("amount"),
                orderReferenceNo = json.string("order_reference_no"),
                transactionId = json.string("transaction_id"),
                totalAmount = json.optionalDouble("total_amount"),
                currency = json.optionalString("currency"),
                remark = json.optionalString("remark"),
                customerName = json.optionalString("customer_name"),
                fee = json.optionalDouble("fee"),
                feeCurrency = json.optionalString("fee_currency"),
                wingAccount = json.optionalString("wing_account"),
                psTrnId = json.optionalString("ps_trn_id"),
                fcTrnId = json.optionalString("fc_trn_id"),
                billerName = json.optionalString("biller_name"),
                transactionDate = json.optionalString("transaction_date"),
                raw = json,
            )
    }
}

/**
 * Response of the authorization API.
 *
 * @property token authorization token (a JWT), on success
 * @property confirmUrl Wing's payment page for [token]: redirect the payer there
 */
public data class WingAuthorizationResponse(
    public val status: WingStatus,
    public val token: String? = null,
    public val confirmUrl: String? = null,
) {
    /** Whether Wing authorized the payment. */
    public val isSuccess: Boolean get() = status.isSuccess && !token.isNullOrEmpty()
}

/** Response of the transaction inquiry API. */
public data class WingInquiryResponse(
    public val status: WingStatus,
    /** the transaction, when [isSuccess] */
    public val transaction: WingTransaction? = null,
) {
    /** Whether Wing found the transaction. */
    public val isSuccess: Boolean get() = status.isSuccess && transaction != null

    /** Whether the transaction was found and its amount is at least [price]. */
    public fun isPaid(price: Number): Boolean = isSuccess && transaction!!.covers(price)

    public companion object {
        /** Parses Wing JSON: the transaction fields are at the top level, or inside `data`. */
        public fun from(json: JsonObject): WingInquiryResponse {
            val status = WingStatus.from(json)
            if (!status.isSuccess) return WingInquiryResponse(status)
            return WingInquiryResponse(status, WingTransaction.from(json.obj("data") ?: json))
        }
    }
}

/** A `Float` as the decimal it prints as (`0.1f` is `0.1`, not `0.10000000149011612`). */
internal fun Number.toDecimalDouble(): Double = if (this is Float) toString().toDouble() else toDouble()
