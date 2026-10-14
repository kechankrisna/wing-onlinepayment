package io.github.kechankrisna.wing.onlinepayment

/**
 * Partner credentials provided by Wing Bank.
 *
 * The REST API key and the password are secrets: keep them on your server,
 * never in an Android or browser app. [toString] leaves them out.
 *
 * @property username username provided by Wing
 * @property restApiKey REST API key provided by Wing (`rest_api_key`)
 * @property password password provided by Wing: the AES-256 key of the
 *   payload, the hash and the callback; its first 16 bytes are the payload IV
 * @property billTillNumber biller code or till number provided by Wing
 * @property referer domain registered with Wing, sent Base64-encoded as the
 *   `Referer` header
 * @property baseUrl [UAT_URL], or the production URL Wing gave you
 * @property sandbox sends `sandbox: "1"` (testing) when true, `"0"`
 *   (production) when false
 */
public data class WingMerchant(
    public val username: String,
    public val restApiKey: String,
    public val password: String,
    public val billTillNumber: String,
    public val referer: String,
    public val baseUrl: String = UAT_URL,
    public val sandbox: Boolean = true,
) {
    /** Keeps the REST API key and password out of logs. */
    override fun toString(): String =
        "WingMerchant(username=$username, restApiKey=***, password=***, billTillNumber=$billTillNumber, " +
            "referer=$referer, baseUrl=$baseUrl, sandbox=$sandbox)"

    public companion object {
        /** Wing online payment UAT (testing) environment; Wing gives the production URL */
        public const val UAT_URL: String = "https://sdk-uat.wingmoney.com/wingonlinesdkv2"
    }
}
