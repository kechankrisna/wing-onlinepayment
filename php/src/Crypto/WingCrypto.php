<?php

declare(strict_types=1);

namespace PhpWing\Crypto;

/**
 * Encryption and hashing of Wing's Web SDK spec. Implement this interface
 * to plug in another backend.
 */
interface WingCrypto
{
    /**
     * `openssl_encrypt($plainText, 'AES-256-CBC', $password, 0, $iv)`: the
     * password NUL-padded or truncated to 32 bytes, a 16-byte IV, base64 out.
     *
     * @throws \InvalidArgumentException when `$iv` is not 16 bytes
     */
    public function aes256CbcEncrypt(string $plainText, string $password, string $iv): string;

    /**
     * Decrypts what {@see aes256CbcEncrypt()} returns.
     *
     * @throws \UnexpectedValueException when it was not encrypted with this password and IV
     * @throws \InvalidArgumentException when `$iv` is not 16 bytes
     */
    public function aes256CbcDecrypt(string $base64CipherText, string $password, string $iv): string;

    /** Uppercase hex SHA-256 of `$message`. */
    public function sha256Upper(string $message): string;
}
