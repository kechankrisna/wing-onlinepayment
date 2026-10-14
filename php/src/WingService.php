<?php

declare(strict_types=1);

namespace PhpWing;

use PhpWing\Crypto\OpenSslCrypto;
use PhpWing\Crypto\WingCrypto;
use PhpWing\Exception\ErrorType;
use PhpWing\Exception\WingException;
use PhpWing\Http\CurlHttpClient;
use PhpWing\Http\HttpClient;
use PhpWing\Model\AuthorizationResponse;
use PhpWing\Model\InquiryResponse;
use PhpWing\Model\Payment;
use PhpWing\Model\Status;
use PhpWing\Model\Transaction;
use Psr\Clock\ClockInterface;
use Psr\Log\LoggerInterface;

/**
 * Wing Bank online payment (Web SDK v2) client.
 *
 * Wing business errors (invalid REST API key, transaction not found, ...)
 * are returned in `status`. A {@see WingException} is thrown only when Wing
 * could not be reached or did not answer with an `errorCode`. Run it on your
 * server: the REST API key and the password are secrets.
 */
final class WingService
{
    public const string AUTHORIZATION_PATH = '/v1/online/payment/authorization';

    /** Wing's payment page, opened by {@see confirmUrl()} */
    public const string CONFIRM_PATH = '/v1/online/payment/confirm';

    /** `v2`, as in section 4.1 of the spec (v2.0.3) and on Wing's staging server. */
    public const string INQUIRY_PATH = '/v2/online/payment/transaction/inquiry';

    /** builds the request bodies; exposed to support new endpoints */
    public readonly RequestBuilder $requestBuilder;

    private readonly WingCrypto $crypto;

    private ?HttpClient $http;

    /**
     * Every dependency except `$merchant` is optional and injectable.
     *
     * @param ?HttpClient $httpClient HTTP stack (default: CurlHttpClient; or a Psr18HttpClient)
     * @param ?ClockInterface $clock PSR-20 source of `timestamp` (default: now)
     * @param ?WingCrypto $crypto AES-256-CBC and SHA-256 (default: ext-openssl)
     * @param ?LoggerInterface $logger PSR-3 logger for request/response logs (debug level, REST API key masked)
     * @param ?\Closure(): string $random source of `rand_str` (default: random_bytes)
     */
    public function __construct(
        public readonly WingMerchant $merchant,
        ?HttpClient $httpClient = null,
        ?ClockInterface $clock = null,
        ?WingCrypto $crypto = null,
        private readonly ?LoggerInterface $logger = null,
        ?\Closure $random = null,
    ) {
        $this->crypto = $crypto ?? new OpenSslCrypto();
        $this->requestBuilder = new RequestBuilder($merchant, $clock, $this->crypto, $random);
        // created on first use, so decrypting a callback needs no ext-curl
        $this->http = $httpClient;
    }

    /**
     * Encrypts and signs `$payment` and asks Wing for a payment token. On
     * success, redirect the payer to `confirmUrl`.
     *
     * @throws \InvalidArgumentException for an amount with more than 2 decimals
     * @throws WingException of type Encryption for a password shorter than 16 bytes
     */
    public function authorize(Payment $payment): AuthorizationResponse
    {
        if (\strlen($this->merchant->password) < 16) {
            throw new WingException(ErrorType::Encryption, 'The Wing password must be at least 16 bytes: its first 16 are the IV');
        }
        $json = $this->post(self::AUTHORIZATION_PATH, $this->requestBuilder->authorization($payment));
        $token = $json['token'] ?? null;
        $token = \is_string($token) ? $token : null;

        return new AuthorizationResponse(
            Status::fromArray($json),
            $token,
            $token === null || $token === '' ? null : $this->confirmUrl($token),
        );
    }

    /** Wing's payment page for an authorization token: `{base}/v1/online/payment/confirm?token=base64(token)`. */
    public function confirmUrl(string $token): string
    {
        return $this->url(self::CONFIRM_PATH) . '?token=' . rawurlencode(base64_encode($token));
    }

    /**
     * Details of the payment of `$orderReferenceNo`. Call it when Wing
     * redirects to your `return_url` with `status=success`, and check
     * `isPaid($price)` before delivering.
     */
    public function inquiry(string $orderReferenceNo): InquiryResponse
    {
        return InquiryResponse::fromArray($this->post(self::INQUIRY_PATH, $this->requestBuilder->inquiry($orderReferenceNo)));
    }

    /**
     * The JSON in the `contents` Wing POSTs to your callback URL, decrypted
     * with the merchant password.
     *
     * @throws WingException of type InvalidCallback when it was not encrypted with the password
     */
    public function decryptCallback(string $contents): string
    {
        try {
            return $this->crypto->aes256CbcDecrypt($contents, $this->merchant->password, OpenSslCrypto::passwordIv($this->merchant->password));
        } catch (\UnexpectedValueException|\InvalidArgumentException $e) {
            throw new WingException(ErrorType::InvalidCallback, 'Callback contents could not be decrypted with the Wing password', null, $e);
        }
    }

    /**
     * Decrypts and parses the body Wing POSTed to your callback URL: the JSON
     * `{"contents": "..."}`, the form `contents=...`, or the value itself.
     * Still confirm with {@see inquiry()} and the amount before delivering.
     *
     * ```php
     * $transaction = $wing->parseCallback(file_get_contents('php://input'));
     * ```
     *
     * @throws WingException of type InvalidCallback
     */
    public function parseCallback(string $body): Transaction
    {
        $decrypted = $this->decryptCallback(self::callbackContents($body));
        try {
            $decoded = json_decode($decrypted, true, 512, JSON_THROW_ON_ERROR);
        } catch (\JsonException $e) {
            throw new WingException(ErrorType::InvalidCallback, 'Decrypted callback is not JSON', null, $e);
        }
        if (!\is_array($decoded) || array_is_list($decoded)) {
            throw new WingException(ErrorType::InvalidCallback, 'Decrypted callback is not a JSON object');
        }

        return Transaction::fromArray($decoded);
    }

    /** The encrypted `contents` of a callback body (see {@see parseCallback()}). */
    public static function callbackContents(string $body): string
    {
        $trimmed = trim($body);
        if (str_starts_with($trimmed, '{')) {
            $decoded = json_decode($trimmed, true);
            if (\is_array($decoded) && \is_string($decoded['contents'] ?? null)) {
                return $decoded['contents'];
            }
        }
        if (str_starts_with($trimmed, 'contents=')) {
            parse_str($trimmed, $form);
            $contents = $form['contents'] ?? '';

            return \is_string($contents) ? $contents : '';
        }

        return $trimmed;
    }

    /**
     * POSTs JSON and returns Wing's reply. Wing answers errors with a JSON
     * body carrying `errorCode`, possibly with a non-2xx HTTP status, which
     * is returned like a success.
     *
     * @param array<string, string> $body
     * @return array<array-key, mixed>
     */
    private function post(string $path, array $body): array
    {
        $url = $this->url($path);
        $json = json_encode($body, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);
        if ($this->logger !== null) {
            $masked = json_encode([...$body, 'rest_api_key' => '***'], JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);
            $this->logger->debug("[Wing] POST {$url} {$masked}");
        }

        $headers = [
            'Accept' => 'application/json',
            'Content-Type' => 'application/json',
            'User-Agent' => 'php-wing/' . Version::SDK_VERSION,
        ];
        if ($this->merchant->referer !== '') {
            $headers['Referer'] = base64_encode($this->merchant->referer);
        }

        try {
            $this->http ??= new CurlHttpClient();
            $response = $this->http->post($url, $headers, $json);
        } catch (WingException $e) {
            $this->logger?->debug("[Wing] failed {$e->getMessage()}");
            throw $e;
        }

        $this->logger?->debug("[Wing] {$response->statusCode} {$response->body}");
        $decoded = json_decode($response->body, true);
        if (\is_array($decoded) && \array_key_exists('errorCode', $decoded)) {
            return $decoded;
        }

        throw new WingException(ErrorType::UnexpectedResponse, 'Unexpected response from Wing', $response->statusCode);
    }

    private function url(string $path): string
    {
        return rtrim($this->merchant->baseApiUrl, '/') . $path;
    }
}
