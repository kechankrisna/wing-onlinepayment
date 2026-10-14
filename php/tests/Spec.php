<?php

declare(strict_types=1);

namespace PhpWing\Tests;

use PhpWing\Model\Payment;
use PhpWing\RequestBuilder;
use PhpWing\WingMerchant;
use Psr\Clock\ClockInterface;

/** Access to the shared spec/ folder and the fixed inputs of the known answers. */
final class Spec
{
    public const string RAND_STR = 'cbae7968ed6d0eff';

    public const string TIMESTAMP = '1624684179';

    /** @return array<string, string> known answers computed with PHP's openssl_encrypt */
    public static function knownAnswers(): array
    {
        /** @var array<string, string> $json */
        $json = json_decode((string) file_get_contents(__DIR__ . '/../../spec/test-vectors/php_known_answers.json'), true, 512, JSON_THROW_ON_ERROR);

        return $json;
    }

    public static function merchant(string $password = 'test-password-0123456789abcdefgh', bool $sandbox = true): WingMerchant
    {
        return new WingMerchant(
            'online.testing',
            'test-rest-api-key',
            $password,
            '2000',
            'https://shop.test',
            'https://wing.test/wingonlinesdkv2/',
            $sandbox,
        );
    }

    public static function clock(): ClockInterface
    {
        return new class implements ClockInterface {
            public function now(): \DateTimeImmutable
            {
                return new \DateTimeImmutable('@' . Spec::TIMESTAMP);
            }
        };
    }

    /** @return \Closure(): string */
    public static function random(): \Closure
    {
        return static fn(): string => self::RAND_STR;
    }

    public static function builder(?WingMerchant $merchant = null): RequestBuilder
    {
        return new RequestBuilder($merchant ?? self::merchant(), self::clock(), null, self::random());
    }

    public static function minimalPayment(): Payment
    {
        return new Payment(
            'c19245baae',
            15,
            'https://shop.test/wing/return?order=c19245baae',
            'https://shop.test/wing/cancel?order=c19245baae',
        );
    }

    private function __construct() {}
}
