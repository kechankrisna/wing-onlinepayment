import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import {
  WingMerchant,
  WingRequestBuilder,
  type Payment,
} from '../src/index.js';

/** spec/test-vectors/php_known_answers.json, computed with PHP's openssl_encrypt */
export const kat = JSON.parse(
  readFileSync(
    fileURLToPath(
      new URL(
        '../../spec/test-vectors/php_known_answers.json',
        import.meta.url,
      ),
    ),
    'utf8',
  ),
) as Record<string, string>;

/** the fixed inputs of spec/test-vectors/php_known_answers.php */
export const password = 'test-password-0123456789abcdefgh';
export const merchant = new WingMerchant({
  username: 'online.testing',
  restApiKey: 'test-rest-api-key',
  password,
  billTillNumber: '2000',
  referer: 'https://shop.test',
  baseUrl: 'https://wing.test/wingonlinesdkv2/',
});
export const randStr = 'cbae7968ed6d0eff';
export const timestamp = '1624684179';
export const fixedClock = () => new Date(1624684179 * 1000);
export const fixedRandom = () => randStr;

export const builder = (m: WingMerchant = merchant) =>
  new WingRequestBuilder(m, { clock: fixedClock, random: fixedRandom });

export const minimalPayment: Payment = {
  orderReferenceNo: 'c19245baae',
  amount: 15,
  returnUrl: 'https://shop.test/wing/return?order=c19245baae',
  cancelUrl: 'https://shop.test/wing/cancel?order=c19245baae',
};

export const fullPayment: Payment = {
  ...minimalPayment,
  integrationType: 'MOBAPP',
  isWingAppInstalled: true,
  itemName: 'កាហ្វេ / coffee',
  merchantName: 'Testing Shop',
  wingAccount: '00001614',
};

/** a `fetch` that records requests and answers with `reply` */
export function fakeFetch(
  reply: (request: Request) => Response | Promise<Response>,
): typeof fetch & { requests: Request[] } {
  const requests: Request[] = [];
  const fn = async (input: string | URL | Request, init?: RequestInit) => {
    const request = new Request(input, init);
    requests.push(request.clone());
    init?.signal?.throwIfAborted();
    return reply(request);
  };
  return Object.assign(fn, { requests });
}

export const jsonReply = (body: unknown, status = 200) =>
  fakeFetch(() => Response.json(body, { status }));
