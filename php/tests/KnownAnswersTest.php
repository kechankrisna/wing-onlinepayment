<?php

declare(strict_types=1);

namespace PhpWing\Tests;

use PHPUnit\Framework\TestCase;
use PhpWing\Enum\IntegrationType;
use PhpWing\Model\Payment;
use PhpWing\RequestBuilder;
use PhpWing\WingService;

/**
 * Payloads, hashes and callbacks must equal the known answers in
 * spec/test-vectors, computed with PHP's openssl_encrypt as in Wing's spec.
 */
final class KnownAnswersTest extends TestCase
{
    public static function fullPayment(): Payment
    {
        return new Payment(
            orderReferenceNo: 'c19245baae',
            amount: 15,
            returnUrl: 'https://shop.test/wing/return?order=c19245baae',
            cancelUrl: 'https://shop.test/wing/cancel?order=c19245baae',
            integrationType: IntegrationType::MobileApp,
            isWingAppInstalled: true,
            itemName: 'កាហ្វេ / coffee',
            merchantName: 'Testing Shop',
            wingAccount: '00001614',
        );
    }

    public function testPayloadWithTheRequiredFieldsOnly(): void
    {
        $kat = Spec::knownAnswers();
        $builder = Spec::builder();
        self::assertSame($kat['payload_minimal_json'], $builder->payloadJson(Spec::minimalPayment(), Spec::RAND_STR, Spec::TIMESTAMP));
        self::assertSame([
            'username' => 'online.testing',
            'rest_api_key' => 'test-rest-api-key',
            'payload' => $kat['payload_minimal'],
            'hash' => $kat['hash'],
            'sandbox' => '1',
        ], $builder->authorization(Spec::minimalPayment()));
    }

    public function testPayloadWithEveryField(): void
    {
        $kat = Spec::knownAnswers();
        $builder = Spec::builder();
        self::assertSame($kat['payload_full_json'], $builder->payloadJson(self::fullPayment(), Spec::RAND_STR, Spec::TIMESTAMP));
        self::assertSame($kat['payload_full'], $builder->authorization(self::fullPayment())['payload']);
    }

    public function testExplicitRandStrAndTimestamp(): void
    {
        $kat = Spec::knownAnswers();
        $body = (new RequestBuilder(Spec::merchant()))->authorization(Spec::minimalPayment(), Spec::RAND_STR, Spec::TIMESTAMP);
        self::assertSame($kat['payload_minimal'], $body['payload']);
        self::assertSame($kat['hash'], $body['hash']);
    }

    public function testHashOfAKhrAmount(): void
    {
        self::assertSame(Spec::knownAnswers()['hash_khr'], Spec::builder()->hash('12000.00', 'c19245baae', Spec::RAND_STR, Spec::TIMESTAMP));
    }

    public function testShortAndLongPasswords(): void
    {
        $kat = Spec::knownAnswers();
        $short = Spec::builder(Spec::merchant($kat['short_password']))->authorization(Spec::minimalPayment());
        self::assertSame($kat['payload_minimal_short_password'], $short['payload']);
        self::assertSame($kat['hash_short_password'], $short['hash']);
        $long = Spec::builder(Spec::merchant($kat['long_password']))->authorization(Spec::minimalPayment());
        self::assertSame($kat['payload_minimal_long_password'], $long['payload']);
    }

    public function testCallbackContents(): void
    {
        $kat = Spec::knownAnswers();
        $wing = new WingService(Spec::merchant());
        self::assertSame($kat['callback_json'], $wing->decryptCallback($kat['callback_contents']));
    }
}
