// Integration tests against Wing's online payment API. They read partner
// credentials from node/.env (see .env.example), from the file named by
// WING_ENV_FILE, or from WING_* environment variables, and are skipped
// without them:
//
//   npx vitest run test/integration.test.ts
//   WING_ENV_FILE=.env.production npx vitest run test/integration.test.ts
//
// They authorize a real payment (0.10 USD, never paid), so credentials with
// WING_SANDBOX="0" are refused unless you also set WING_ALLOW_PRODUCTION=true.
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { describe, expect, it } from 'vitest';

import { CONFIRM_PATH, WingMerchant, WingService } from '../src/index.js';

const nodeDir = fileURLToPath(new URL('..', import.meta.url));
const envFile = resolve(nodeDir, process.env['WING_ENV_FILE'] ?? '.env');
if (existsSync(envFile)) process.loadEnvFile(envFile);

const env = (key: string) => process.env[key] ?? '';
const isProduction = env('WING_SANDBOX') === '0';
const allowProduction = process.env['WING_ALLOW_PRODUCTION'] === 'true';
const hasCredentials =
  env('WING_USERNAME') !== '' && env('WING_PASSWORD') !== '';

if (!hasCredentials) {
  console.info(`Wing integration tests skipped: no credentials (${envFile})`);
} else if (isProduction && !allowProduction) {
  console.info(
    'Wing integration tests skipped: WING_SANDBOX="0"; ' +
      'set WING_ALLOW_PRODUCTION=true to run tests that authorize real payments',
  );
}

describe.skipIf(!hasCredentials || (isProduction && !allowProduction))(
  'Wing online payment',
  () => {
    const referer = env('WING_REFERER_DOMAIN') || 'https://example.com';
    const wing = new WingService({
      merchant: new WingMerchant({
        username: env('WING_USERNAME'),
        restApiKey: env('WING_REST_API_KEY'),
        password: env('WING_PASSWORD'),
        billTillNumber: env('WING_BILL_TILL_NUMBER'),
        referer,
        baseUrl: env('WING_API_URL') || WingMerchant.UAT_URL,
        sandbox: !isProduction,
      }),
      logger: (line) => {
        console.info(line);
      },
    });
    const order = `node${String(Date.now())}`;

    it('authorize returns the payment page', async () => {
      const response = await wing.authorize({
        orderReferenceNo: order,
        amount: 0.1,
        returnUrl: `${referer}/wing/return`,
        cancelUrl: `${referer}/wing/cancel`,
        itemName: 'node integration test',
      });
      expect(response.isSuccess, JSON.stringify(response.status)).toBe(true);
      expect(response.confirmUrl).toContain(`${CONFIRM_PATH}?token=`);
    });

    it('inquiry of an unpaid order is reported, not thrown', async () => {
      const response = await wing.inquiry(order);
      expect(response.isPaid(0.1)).toBe(false);
    });
  },
);
