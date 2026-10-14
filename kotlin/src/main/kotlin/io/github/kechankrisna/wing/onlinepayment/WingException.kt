package io.github.kechankrisna.wing.onlinepayment

/** What went wrong in a [WingException]. */
public enum class WingErrorType {
    /** Wing could not be reached (DNS, refused connection, offline, ...) */
    CONNECTION,

    /** the request took longer than the configured timeout */
    TIMEOUT,

    /**
     * the HTTP request was cancelled while the calling coroutine was still
     * active; cancelling the coroutine itself throws `CancellationException`
     */
    CANCELLED,

    /** Wing's TLS certificate was rejected */
    BAD_CERTIFICATE,

    /** Wing answered without an `errorCode` (e.g. an HTML page) */
    UNEXPECTED_RESPONSE,

    /** the payload could not be encrypted (e.g. a password shorter than 16 bytes) */
    ENCRYPTION,

    /** callback contents do not decrypt with the password, or are not a JSON object */
    INVALID_CALLBACK,

    /** any other failure; see [WingException.cause] */
    UNKNOWN,
}

/**
 * Thrown when Wing could not be reached or did not answer with an
 * `errorCode`, and for invalid local input such as a short password. Branch
 * on [type].
 *
 * Wing business errors (invalid REST API key, transaction not found, ...)
 * are not thrown: they are returned in the response `status`.
 *
 * @property type what went wrong
 * @property statusCode HTTP status code, when a response was received
 */
public class WingException(
    public val type: WingErrorType,
    message: String,
    public val statusCode: Int? = null,
    cause: Throwable? = null,
) : RuntimeException(message, cause) {
    /** Whether retrying the same call later may succeed. */
    public val isRetryable: Boolean
        get() =
            when (type) {
                WingErrorType.CONNECTION, WingErrorType.TIMEOUT -> true
                WingErrorType.UNEXPECTED_RESPONSE -> (statusCode ?: 0) >= 500
                else -> false
            }

    override fun toString(): String =
        if (statusCode == null) {
            "WingException($type): $message"
        } else {
            "WingException($type): $message (HTTP $statusCode)"
        }
}
