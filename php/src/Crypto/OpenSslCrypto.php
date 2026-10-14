<?php

declare(strict_types=1);

namespace PhpWing\Crypto;

/** Default {@see WingCrypto}, backed by ext-openssl, as in Wing's PHP sample. */
final class OpenSslCrypto implements WingCrypto
{
    private const string CIPHER = 'AES-256-CBC';

    public function aes256CbcEncrypt(string $plainText, #[\SensitiveParameter] string $password, string $iv): string
    {
        self::checkIv($iv);
        $encrypted = openssl_encrypt($plainText, self::CIPHER, $password, 0, $iv);
        if ($encrypted === false) {
            throw new \RuntimeException('AES encryption failed: ' . (openssl_error_string() ?: 'unknown error'));
        }

        return $encrypted;
    }

    public function aes256CbcDecrypt(string $base64CipherText, #[\SensitiveParameter] string $password, string $iv): string
    {
        self::checkIv($iv);
        $raw = base64_decode(trim($base64CipherText), true);
        $plain = $raw === false ? false : openssl_decrypt($raw, self::CIPHER, $password, OPENSSL_RAW_DATA, $iv);
        if ($plain === false || preg_match('//u', $plain) !== 1) {
            // clear the queue so later calls report their own errors
            while (openssl_error_string() !== false) {
            }

            throw new \UnexpectedValueException('not encrypted with this password');
        }

        return $plain;
    }

    public function sha256Upper(string $message): string
    {
        return strtoupper(hash('sha256', $message));
    }

    /**
     * The first 16 bytes of `$password`, the IV of the payload and the callback.
     *
     * @throws \InvalidArgumentException for a shorter password
     */
    public static function passwordIv(#[\SensitiveParameter] string $password): string
    {
        if (\strlen($password) < 16) {
            throw new \InvalidArgumentException('the Wing password must be at least 16 bytes: its first 16 are the IV');
        }

        return substr($password, 0, 16);
    }

    private static function checkIv(string $iv): void
    {
        if (\strlen($iv) !== 16) {
            throw new \InvalidArgumentException('the IV must be 16 bytes, got ' . \strlen($iv));
        }
    }
}
