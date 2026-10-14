<?php

declare(strict_types=1);

namespace PhpWing;

use PhpWing\Crypto\OpenSslCrypto;
use PhpWing\Crypto\WingCrypto;
use PhpWing\Model\Payment;
use Psr\Clock\ClockInterface;

/**
 * Builds the encrypted and hashed request bodies of the Wing online payment
 * APIs:
 *
 * - `payload` is `AES-256-CBC(JSON, password, first 16 bytes of password)`
 * - `hash` is `UPPERCASE(SHA256(AES-256-CBC(base64(username#rest_api_key#
 *   bill_till_number#amount#order_reference_no#rand_str#timestamp), password, rand_str)))`
 *
 * with AES output in base64, as `openssl_encrypt` returns it.
 */
final readonly class RequestBuilder
{
    private ClockInterface $clock;

    private WingCrypto $crypto;

    /** @var \Closure(): string */
    private \Closure $random;

    /**
     * @param ?ClockInterface $clock PSR-20 source of `timestamp` (default: now)
     * @param ?\Closure(): string $random source of `rand_str` (default: {@see randomString()})
     */
    public function __construct(
        private WingMerchant $merchant,
        ?ClockInterface $clock = null,
        ?WingCrypto $crypto = null,
        ?\Closure $random = null,
    ) {
        $this->clock = $clock ?? new SystemClock();
        $this->crypto = $crypto ?? new OpenSslCrypto();
        $this->random = $random ?? self::randomString(...);
    }

    /**
     * Body of the authorization API: `username`, `rest_api_key`, `payload`,
     * `hash` and `sandbox`.
     *
     * @return array<string, string>
     *
     * @throws \InvalidArgumentException for an amount with more than 2 decimals,
     *   a malformed `$randStr` or `$timestamp`, or a password shorter than 16 bytes
     */
    public function authorization(Payment $payment, ?string $randStr = null, ?string $timestamp = null): array
    {
        $rand = $this->randStr($randStr);
        $time = $this->timestamp($timestamp);

        return [
            'username' => $this->merchant->username,
            'rest_api_key' => $this->merchant->restApiKey,
            'payload' => $this->crypto->aes256CbcEncrypt(
                $this->payloadJson($payment, $rand, $time),
                $this->merchant->password,
                OpenSslCrypto::passwordIv($this->merchant->password),
            ),
            'hash' => $this->hash(self::formatAmount($payment->amount), $payment->orderReferenceNo, $rand, $time),
            'sandbox' => $this->sandbox(),
        ];
    }

    /** The JSON encrypted into `payload`, in the order of the spec's sample; absent optional fields are left out. */
    public function payloadJson(Payment $payment, string $randStr, string $timestamp): string
    {
        $fields = [
            'amount' => self::formatAmount($payment->amount),
            'bill_till_number' => $this->merchant->billTillNumber,
            'order_reference_no' => $payment->orderReferenceNo,
            'return_url' => $payment->returnUrl,
            'cancel_url' => $payment->cancelUrl,
            'rand_str' => $randStr,
            'timestamp' => $timestamp,
            'wing_account' => $payment->wingAccount,
            'integration_type' => $payment->integrationType->value,
            'is_wingapp_installed' => $payment->isWingAppInstalled ? '1' : '0',
            'item_name' => $payment->itemName,
            'merchant_name' => $payment->merchantName,
        ];

        return json_encode(
            array_filter($fields, static fn($v) => $v !== null),
            JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE,
        );
    }

    /** `hash` of an authorization; `$amount` as formatted by {@see formatAmount()}. */
    public function hash(string $amount, string $orderReferenceNo, string $randStr, string $timestamp): string
    {
        $plain = implode('#', [
            $this->merchant->username,
            $this->merchant->restApiKey,
            $this->merchant->billTillNumber,
            $amount,
            $orderReferenceNo,
            $randStr,
            $timestamp,
        ]);

        return $this->crypto->sha256Upper(
            $this->crypto->aes256CbcEncrypt(base64_encode($plain), $this->merchant->password, $this->randStr($randStr)),
        );
    }

    /** @return array<string, string> body of the transaction inquiry API */
    public function inquiry(string $orderReferenceNo): array
    {
        return [
            'username' => $this->merchant->username,
            'rest_api_key' => $this->merchant->restApiKey,
            'order_reference_no' => $orderReferenceNo,
            'sandbox' => $this->sandbox(),
        ];
    }

    /** 16 random characters among `0-9` and `a-f`, from a secure source. */
    public static function randomString(): string
    {
        return bin2hex(random_bytes(8));
    }

    /**
     * `$amount` with 2 decimals, as Wing requires (`5.00`, `2.50`, `12000.00`).
     *
     * @throws \InvalidArgumentException when it is not positive or has more than 2 decimals
     */
    public static function formatAmount(int|float $amount): string
    {
        if (!is_finite((float) $amount) || $amount <= 0 || $amount >= 1e13) {
            throw new \InvalidArgumentException("amount must be positive and below 1e13, got {$amount}");
        }
        $cents = (int) round($amount * 100);
        if ($cents / 100 != $amount) {
            throw new \InvalidArgumentException("amount must have at most 2 decimals, got {$amount}");
        }

        return \sprintf('%d.%02d', intdiv($cents, 100), $cents % 100);
    }

    private function sandbox(): string
    {
        return $this->merchant->sandbox ? '1' : '0';
    }

    private function randStr(?string $randStr): string
    {
        $value = $randStr ?? ($this->random)();
        if (preg_match('/^[0-9a-f]{16}$/D', $value) !== 1) {
            throw new \InvalidArgumentException("rand_str must be 16 characters among 0-9 and a-f, got \"{$value}\"");
        }

        return $value;
    }

    private function timestamp(?string $timestamp): string
    {
        $value = $timestamp ?? (string) $this->clock->now()->getTimestamp();
        if (preg_match('/^\d+$/D', $value) !== 1) {
            throw new \InvalidArgumentException("timestamp must be Unix seconds, got \"{$value}\"");
        }

        return $value;
    }
}
