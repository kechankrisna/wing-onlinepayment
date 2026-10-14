<?php

declare(strict_types=1);

namespace PhpWing;

/**
 * Partner credentials provided by Wing Bank. The REST API key and the
 * password are secrets: keep them on your server.
 */
final readonly class WingMerchant
{
    /** Wing online payment UAT (testing) environment; Wing gives the production URL */
    public const string UAT_URL = 'https://sdk-uat.wingmoney.com/wingonlinesdkv2';

    /**
     * @param string $username username provided by Wing
     * @param string $restApiKey REST API key provided by Wing (`rest_api_key`)
     * @param string $password password provided by Wing: the AES-256 key; its first 16 bytes are the payload IV
     * @param string $billTillNumber biller code or till number provided by Wing (`bill_till_number`)
     * @param string $referer domain registered with Wing, sent Base64-encoded as `Referer`
     * @param string $baseApiUrl {@see UAT_URL} or the production URL Wing gave you
     * @param bool $sandbox sends `sandbox: "1"` (testing) when true, `"0"` (production) when false
     */
    public function __construct(
        public string $username,
        #[\SensitiveParameter]
        public string $restApiKey,
        #[\SensitiveParameter]
        public string $password,
        public string $billTillNumber,
        public string $referer,
        public string $baseApiUrl = self::UAT_URL,
        public bool $sandbox = true,
    ) {}

    /**
     * Keeps the REST API key and password out of var_dump() and print_r().
     *
     * @return array<string, string|bool>
     */
    public function __debugInfo(): array
    {
        return [
            'username' => $this->username,
            'restApiKey' => '***',
            'password' => '***',
            'billTillNumber' => $this->billTillNumber,
            'referer' => $this->referer,
            'baseApiUrl' => $this->baseApiUrl,
            'sandbox' => $this->sandbox,
        ];
    }
}
