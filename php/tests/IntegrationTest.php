<?php

declare(strict_types=1);

namespace PhpWing\Tests;

use PHPUnit\Framework\Attributes\Depends;
use PHPUnit\Framework\Attributes\Group;
use PHPUnit\Framework\TestCase;
use PhpWing\Model\Payment;
use PhpWing\WingMerchant;
use PhpWing\WingService;

/**
 * Integration tests against Wing's online payment API. They read partner
 * credentials from php/.env (or the file named by WING_ENV_FILE) and are
 * skipped without one:
 *
 *   composer test -- --group integration
 *   WING_ENV_FILE=php/.env.production composer test -- --group integration
 *
 * They authorize a real payment (0.10 USD, never paid), so a file with
 * WING_SANDBOX="0" is refused unless you also set WING_ALLOW_PRODUCTION=true.
 */
#[Group('integration')]
final class IntegrationTest extends TestCase
{
    private static ?WingService $wing = null;

    private static string $order = '';

    private static string $referer = '';

    public static function setUpBeforeClass(): void
    {
        $file = getenv('WING_ENV_FILE') ?: __DIR__ . '/../.env';
        if (!is_file($file)) {
            return;
        }
        $env = self::readEnv($file);
        $production = ($env['WING_SANDBOX'] ?? '1') === '0';
        if ($production && getenv('WING_ALLOW_PRODUCTION') !== 'true') {
            return;
        }
        self::$referer = $env['WING_REFERER_DOMAIN'] ?? 'https://example.com';
        self::$wing = new WingService(new WingMerchant(
            $env['WING_USERNAME'] ?? '',
            $env['WING_REST_API_KEY'] ?? '',
            $env['WING_PASSWORD'] ?? '',
            $env['WING_BILL_TILL_NUMBER'] ?? '',
            self::$referer,
            $env['WING_API_URL'] ?? WingMerchant::UAT_URL,
            !$production,
        ));
        self::$order = 'sdk' . (int) (microtime(true) * 1000);
    }

    protected function setUp(): void
    {
        if (self::$wing === null) {
            self::markTestSkipped('no Wing env file, or it sets WING_SANDBOX="0" without WING_ALLOW_PRODUCTION=true');
        }
    }

    private static function wing(): WingService
    {
        \assert(self::$wing !== null);

        return self::$wing;
    }

    public function testAuthorizeReturnsThePaymentPage(): void
    {
        $response = self::wing()->authorize(new Payment(
            self::$order,
            0.1,
            self::$referer . '/wing/return',
            self::$referer . '/wing/cancel',
            itemName: 'php_wing integration test',
        ));
        self::assertTrue($response->isSuccess(), $response->status->code . ' ' . $response->status->message);
        self::assertStringContainsString(WingService::CONFIRM_PATH . '?token=', (string) $response->confirmUrl);
    }

    #[Depends('testAuthorizeReturnsThePaymentPage')]
    public function testUnpaidOrderIsReportedNotThrown(): void
    {
        $response = self::wing()->inquiry(self::$order);
        self::assertFalse($response->isPaid(0.1), $response->status->code . ' ' . $response->status->message);
    }

    /** @return array<string, string> KEY="value" lines of a .env file */
    private static function readEnv(string $file): array
    {
        $env = [];
        foreach (file($file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) ?: [] as $line) {
            if (preg_match('/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/', $line, $m) === 1) {
                $env[$m[1]] = trim($m[2], "\"'");
            }
        }

        return $env;
    }
}
