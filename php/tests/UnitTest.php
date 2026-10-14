<?php

declare(strict_types=1);

namespace PhpWing\Tests;

use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;
use PhpWing\Crypto\OpenSslCrypto;
use PhpWing\Exception\ErrorType;
use PhpWing\Exception\WingException;
use PhpWing\Http\HttpResponse;
use PhpWing\Model\Transaction;
use PhpWing\RequestBuilder;
use PhpWing\Version;
use PhpWing\WingService;

/** Offline tests of the PHP specifics: injected HTTP, errors, parsing. */
final class UnitTest extends TestCase
{
    private static function service(FakeHttpClient $http): WingService
    {
        return new WingService(Spec::merchant(), $http, Spec::clock(), null, null, Spec::random());
    }

    public function testAmountsHaveTwoDecimals(): void
    {
        self::assertSame('15.00', RequestBuilder::formatAmount(15));
        self::assertSame('2.50', RequestBuilder::formatAmount(2.5));
        self::assertSame('0.07', RequestBuilder::formatAmount(0.07));
        self::assertSame('12000.00', RequestBuilder::formatAmount(12000));
        self::assertSame('1234567.89', RequestBuilder::formatAmount(1234567.89));
    }

    /** @return iterable<string, array{int|float}> */
    public static function invalidAmounts(): iterable
    {
        yield 'three decimals' => [1.005];
        yield 'float noise' => [0.1 + 0.2];
        yield 'zero' => [0];
        yield 'negative' => [-1];
        yield 'NaN' => [NAN];
        yield 'too large' => [1e13];
    }

    #[DataProvider('invalidAmounts')]
    public function testAmountsWingWouldRoundAreRejected(int|float $amount): void
    {
        $this->expectException(\InvalidArgumentException::class);
        RequestBuilder::formatAmount($amount);
    }

    public function testRandStrAndTimestamp(): void
    {
        self::assertMatchesRegularExpression('/^[0-9a-f]{16}$/', RequestBuilder::randomString());
        self::assertNotSame(RequestBuilder::randomString(), RequestBuilder::randomString());
        $payload = (new OpenSslCrypto())->aes256CbcDecrypt(
            Spec::builder()->authorization(Spec::minimalPayment())['payload'],
            Spec::merchant()->password,
            OpenSslCrypto::passwordIv(Spec::merchant()->password),
        );
        self::assertStringContainsString('"timestamp":"1624684179"', $payload);

        $this->expectException(\InvalidArgumentException::class);
        Spec::builder()->authorization(Spec::minimalPayment(), 'XYZ');
    }

    public function testProductionSendsSandboxZero(): void
    {
        self::assertSame('0', Spec::builder(Spec::merchant(sandbox: false))->authorization(Spec::minimalPayment())['sandbox']);
        self::assertSame(
            ['username' => 'online.testing', 'rest_api_key' => 'test-rest-api-key', 'order_reference_no' => 'x', 'sandbox' => '1'],
            Spec::builder()->inquiry('x'),
        );
    }

    public function testAuthorizePostsJsonWithABase64Referer(): void
    {
        $http = FakeHttpClient::json(['errorCode' => '200', 'errorText' => 'Success authorization', 'token' => 'eyJhbGciOiJIUzI1NiJ9.e30.sig']);

        $response = self::service($http)->authorize(Spec::minimalPayment());

        self::assertTrue($response->isSuccess());
        self::assertSame(
            'https://wing.test/wingonlinesdkv2/v1/online/payment/confirm?token=' . rawurlencode(base64_encode('eyJhbGciOiJIUzI1NiJ9.e30.sig')),
            $response->confirmUrl,
        );
        $request = $http->requests[0];
        self::assertSame('https://wing.test/wingonlinesdkv2' . WingService::AUTHORIZATION_PATH, $request['url']);
        self::assertSame('application/json', $request['headers']['Content-Type']);
        self::assertSame(base64_encode('https://shop.test'), $request['headers']['Referer']);
        self::assertSame('php-wing/' . Version::SDK_VERSION, $request['headers']['User-Agent']);
        self::assertSame(Spec::builder()->authorization(Spec::minimalPayment()), json_decode($request['body'], true));
    }

    public function testConfirmUrlPercentEncodesTheToken(): void
    {
        $url = (new WingService(Spec::merchant()))->confirmUrl("\xfb\xff");
        self::assertStringEndsWith('?token=' . rawurlencode('+/8='), $url);
    }

    public function testWingErrorIsReturnedNotThrown(): void
    {
        $response = self::service(FakeHttpClient::json(['errorCode' => '401', 'errorText' => 'Invalid rest api key.', 'token' => null], 401))
            ->authorize(Spec::minimalPayment());
        self::assertFalse($response->isSuccess());
        self::assertSame('401', $response->status->code);
        self::assertNull($response->confirmUrl);
    }

    public function testShortPasswordIsAnEncryptionError(): void
    {
        try {
            (new WingService(Spec::merchant('too-short')))->authorize(Spec::minimalPayment());
            self::fail('expected a WingException');
        } catch (WingException $e) {
            self::assertSame(ErrorType::Encryption, $e->type);
        }
    }

    public function testInquiryAtTheTopLevel(): void
    {
        $http = FakeHttpClient::json([
            'errorCode' => '200',
            'respType' => 'respType',
            'amount' => '15.00',
            'total_amount' => 15.0,
            'currency' => 'USD',
            'order_reference_no' => 'c19245baae',
            'transaction_id' => '0002355252200023',
        ]);

        $response = self::service($http)->inquiry('c19245baae');

        self::assertTrue($response->isSuccess());
        self::assertSame(15.0, $response->transaction?->amount);
        self::assertSame('respType', $response->transaction->raw['respType'] ?? null);
        self::assertTrue($response->isPaid(15));
        self::assertFalse($response->isPaid(15.01));
        self::assertSame('https://wing.test/wingonlinesdkv2' . WingService::INQUIRY_PATH, $http->requests[0]['url']);
        self::assertSame(Spec::builder()->inquiry('c19245baae'), json_decode($http->requests[0]['body'], true));
    }

    public function testInquiryInsideData(): void
    {
        $response = self::service(FakeHttpClient::json(['errorCode' => '200', 'data' => ['amount' => 2.5, 'transaction_id' => 'T1']]))->inquiry('x');
        self::assertSame('T1', $response->transaction?->transactionId);
        self::assertTrue($response->isPaid(2.5));
    }

    public function testTransactionNotFoundIsReturned(): void
    {
        $response = self::service(FakeHttpClient::json(['errorCode' => '006035', 'errorText' => 'Transaction not found...!']))->inquiry('x');
        self::assertFalse($response->isSuccess());
        self::assertSame('006035', $response->status->code);
        self::assertNull($response->transaction);
        self::assertFalse($response->isPaid(1));
    }

    public function testHtmlErrorPageIsUnexpected(): void
    {
        $http = new FakeHttpClient(static fn(): HttpResponse => new HttpResponse(502, '<html>'));
        try {
            self::service($http)->inquiry('x');
            self::fail('expected a WingException');
        } catch (WingException $e) {
            self::assertSame(ErrorType::UnexpectedResponse, $e->type);
            self::assertSame(502, $e->statusCode);
            self::assertTrue($e->isRetryable());
        }
    }

    public function testTransportErrorsPropagate(): void
    {
        $http = new FakeHttpClient(static fn(): HttpResponse => throw new WingException(ErrorType::Connection, 'Could not connect to Wing'));
        $this->expectExceptionObject(new WingException(ErrorType::Connection, 'Could not connect to Wing'));
        self::service($http)->inquiry('x');
    }

    public function testCallbackBodiesParse(): void
    {
        $contents = Spec::knownAnswers()['callback_contents'];
        $wing = new WingService(Spec::merchant());
        foreach ([json_encode(['contents' => $contents]), 'contents=' . urlencode($contents), $contents] as $body) {
            $callback = $wing->parseCallback((string) $body);
            self::assertSame('0002355252200023', $callback->transactionId);
            self::assertSame('1234321', $callback->orderReferenceNo);
            self::assertSame(1.5, $callback->amount);
            self::assertSame('USD', $callback->currency);
            self::assertSame(' ONL015627', $callback->raw['ps_trn_id']);
            self::assertTrue($callback->covers(1.5));
            self::assertFalse($callback->covers(1.51));
        }
    }

    public function testCallbacksFromAnotherPasswordAreRejected(): void
    {
        $other = new WingService(Spec::merchant('another-password-0123456789'));
        foreach ([Spec::knownAnswers()['callback_contents'], 'not base64!', base64_encode('short')] as $contents) {
            try {
                $other->parseCallback($contents);
                self::fail('expected a WingException');
            } catch (WingException $e) {
                self::assertSame(ErrorType::InvalidCallback, $e->type);
            }
        }
    }

    public function testCallbackThatIsNotAnObjectIsRejected(): void
    {
        $password = Spec::merchant()->password;
        $contents = (new OpenSslCrypto())->aes256CbcEncrypt('[1]', $password, OpenSslCrypto::passwordIv($password));
        $this->expectException(WingException::class);
        (new WingService(Spec::merchant()))->parseCallback($contents);
    }

    public function testNumbersSentAsStringsParse(): void
    {
        $transaction = Transaction::fromArray(['amount' => '10.5', 'fee' => 0, 'transaction_id' => 123]);
        self::assertSame(10.5, $transaction->amount);
        self::assertSame(0.0, $transaction->fee);
        self::assertSame('123', $transaction->transactionId);
    }

    public function testSecretsAreHiddenFromDebugOutputAndLogs(): void
    {
        $dump = print_r(Spec::merchant(), true);
        self::assertStringNotContainsString('test-rest-api-key', $dump);
        self::assertStringNotContainsString('test-password', $dump);

        $logger = new class extends \Psr\Log\AbstractLogger {
            /** @var list<string> */
            public array $lines = [];

            public function log($level, \Stringable|string $message, array $context = []): void
            {
                $this->lines[] = (string) $message;
            }
        };
        $http = FakeHttpClient::json(['errorCode' => '006035', 'errorText' => 'x']);
        (new WingService(Spec::merchant(), $http, logger: $logger))->inquiry('x');
        self::assertCount(2, $logger->lines);
        self::assertStringNotContainsString('test-rest-api-key', implode("\n", $logger->lines));
    }
}
