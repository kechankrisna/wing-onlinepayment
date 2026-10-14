package io.github.kechankrisna.wing.onlinepayment

import kotlinx.coroutines.future.await
import java.io.IOException
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.net.http.HttpTimeoutException
import java.security.cert.CertificateException
import java.time.Duration
import javax.net.ssl.SSLPeerUnverifiedException

/** An HTTP reply: status code and body. */
public class WingHttpResponse(
    /** HTTP status code */
    public val statusCode: Int,
    /** response body, decoded as UTF-8 */
    public val body: String,
) {
    override fun toString(): String = "WingHttpResponse(statusCode=$statusCode, body=$body)"
}

/**
 * Sends one POST request. Implement it to plug in any HTTP stack (OkHttp,
 * Ktor client, a test fake, ...); the default is [JdkWingHttpClient].
 */
public fun interface WingHttpClient {
    /**
     * POSTs [body] to [url] with [headers] and returns the reply, whatever
     * its status code. Throw when no reply was received: a
     * [WingException], or any exception (an [IOException],
     * [HttpTimeoutException], ...), which the service maps to a
     * [WingErrorType].
     */
    public suspend fun post(
        url: String,
        headers: Map<String, String>,
        body: ByteArray,
    ): WingHttpResponse
}

/**
 * Default [WingHttpClient], backed by the JDK's `java.net.http.HttpClient`.
 * TLS certificates are always verified and redirects are not followed.
 *
 * @param client the JDK client to send with, reused for every call
 * @param timeout whole request timeout
 */
public class JdkWingHttpClient(
    private val client: HttpClient = defaultClient(),
    private val timeout: Duration = DEFAULT_TIMEOUT,
) : WingHttpClient {
    override suspend fun post(
        url: String,
        headers: Map<String, String>,
        body: ByteArray,
    ): WingHttpResponse {
        val request =
            HttpRequest
                .newBuilder(URI.create(url))
                .timeout(timeout)
                .POST(HttpRequest.BodyPublishers.ofByteArray(body))
                .apply { headers.forEach { (name, value) -> header(name, value) } }
                .build()
        val response = client.sendAsync(request, HttpResponse.BodyHandlers.ofString(Charsets.UTF_8)).await()
        return WingHttpResponse(response.statusCode(), response.body() ?: "")
    }

    public companion object {
        /** default connect and request timeout */
        public val DEFAULT_TIMEOUT: Duration = Duration.ofSeconds(60)

        /** HTTP/1.1 (as Wing's samples use), 60 s connect timeout, no redirects. */
        public fun defaultClient(): HttpClient =
            HttpClient
                .newBuilder()
                .version(HttpClient.Version.HTTP_1_1)
                .connectTimeout(DEFAULT_TIMEOUT)
                .followRedirects(HttpClient.Redirect.NEVER)
                .build()
    }
}

/** Maps a failure of [WingHttpClient.post] to a [WingException]. */
internal fun transportException(error: Throwable): WingException =
    when {
        error is WingException -> {
            error
        }

        error.causes().any { it is HttpTimeoutException || it is java.net.SocketTimeoutException } -> {
            WingException(WingErrorType.TIMEOUT, "Timeout with Wing", cause = error)
        }

        error.causes().any { it is CertificateException || it is SSLPeerUnverifiedException } -> {
            WingException(WingErrorType.BAD_CERTIFICATE, "Bad certificate from Wing", cause = error)
        }

        error is java.util.concurrent.CancellationException -> {
            WingException(WingErrorType.CANCELLED, "Request to Wing was cancelled", cause = error)
        }

        error is IOException -> {
            WingException(WingErrorType.CONNECTION, "Could not connect to Wing", cause = error)
        }

        else -> {
            WingException(WingErrorType.UNKNOWN, "Request to Wing failed: ${error.message ?: error}", cause = error)
        }
    }

private fun Throwable.causes(): Sequence<Throwable> = generateSequence(this) { it.cause?.takeIf { cause -> cause !== it } }.take(MAX_CAUSES)

private const val MAX_CAUSES = 16
