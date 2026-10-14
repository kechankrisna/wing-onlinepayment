import { readFileSync } from 'node:fs';
import { inspect } from 'node:util';

import { describe, expect, it } from 'vitest';

import {
  AUTHORIZATION_PATH,
  INQUIRY_PATH,
  NodeWingCrypto,
  SDK_VERSION,
  WingError,
  WingService,
  formatAmount,
  passwordIv,
  randomString,
  transactionFromJson,
} from '../src/index.js';
import {
  builder,
  fakeFetch,
  fixedClock,
  fixedRandom,
  jsonReply,
  kat,
  merchant,
  minimalPayment,
  password,
} from './helpers.js';

const service = (fetch: typeof globalThis.fetch) =>
  new WingService({
    merchant,
    fetch,
    clock: fixedClock,
    random: fixedRandom,
  });

const errorType = async (promise: Promise<unknown>) => {
  try {
    await promise;
  } catch (error) {
    return error instanceof WingError ? error : undefined;
  }
  return undefined;
};

describe('inputs', () => {
  it('amounts have 2 decimals', () => {
    expect(formatAmount(15)).toBe('15.00');
    expect(formatAmount(2.5)).toBe('2.50');
    expect(formatAmount(0.07)).toBe('0.07');
    expect(formatAmount(12000)).toBe('12000.00');
    expect(formatAmount(1234567.89)).toBe('1234567.89');
  });

  it.each([1.005, 0.1 + 0.2, 0, -1, NaN, 1e13])(
    'amount %s is rejected: Wing would round it',
    (amount) => {
      expect(() => formatAmount(amount)).toThrow(RangeError);
    },
  );

  it('rand_str and timestamp', () => {
    const values = new Set(Array.from({ length: 20 }, randomString));
    expect(values.size).toBe(20);
    for (const value of values) expect(value).toMatch(/^[0-9a-f]{16}$/);
    const payload = new NodeWingCrypto().aes256CbcDecrypt(
      builder().authorization(minimalPayment)['payload']!,
      password,
      passwordIv(password),
    );
    expect(payload).toContain('"timestamp":"1624684179"');
    expect(() =>
      builder().authorization(minimalPayment, { randStr: 'XYZ' }),
    ).toThrow(RangeError);
    expect(() =>
      builder().authorization(minimalPayment, { timestamp: '2026-01-02' }),
    ).toThrow(RangeError);
  });

  it('production sends sandbox 0', () => {
    expect(
      builder(merchant.with({ sandbox: false })).authorization(minimalPayment)[
        'sandbox'
      ],
    ).toBe('0');
    expect(builder().inquiry('x')).toEqual({
      username: 'online.testing',
      rest_api_key: 'test-rest-api-key',
      order_reference_no: 'x',
      sandbox: '1',
    });
  });
});

describe('WingService', () => {
  it('authorize posts JSON with a Base64 Referer', async () => {
    const token = 'eyJhbGciOiJIUzI1NiJ9.e30.sig';
    const fetch = jsonReply({
      errorCode: '200',
      errorText: 'Success authorization',
      token,
    });

    const response = await service(fetch).authorize(minimalPayment);

    expect(response.isSuccess).toBe(true);
    expect(response.confirmUrl).toBe(
      'https://wing.test/wingonlinesdkv2/v1/online/payment/confirm?token=' +
        encodeURIComponent(Buffer.from(token).toString('base64')),
    );
    const request = fetch.requests[0]!;
    expect(request.url).toBe(
      `https://wing.test/wingonlinesdkv2${AUTHORIZATION_PATH}`,
    );
    expect(request.headers.get('content-type')).toBe('application/json');
    expect(request.headers.get('user-agent')).toBe(`node-wing/${SDK_VERSION}`);
    expect(await request.json()).toEqual(
      builder().authorization(minimalPayment),
    );
  });

  it('confirmUrl percent-encodes the Base64 token', () => {
    // base64 of these bytes holds '+', '/' and '='
    const url = new WingService({ merchant }).confirmUrl('ûÿ');
    expect(url).not.toMatch(/token=.*[+/=]/);
    expect(new URL(url).searchParams.get('token')).toBe(
      Buffer.from('ûÿ').toString('base64'),
    );
  });

  it('sends the Referer Base64-encoded', async () => {
    // fetch() drops a Referer it cannot use, so check what the service passes
    let headers: Record<string, string> = {};
    const fetch = ((_url: string | URL | Request, init?: RequestInit) => {
      headers = init?.headers as Record<string, string>;
      return Promise.resolve(
        Response.json({ errorCode: '006035', errorText: 'x' }),
      );
    }) as typeof globalThis.fetch;
    await service(fetch).inquiry('x');
    expect(headers['Referer']).toBe(
      Buffer.from('https://shop.test').toString('base64'),
    );
  });

  it('a Wing error is returned, not thrown, whatever the HTTP status', async () => {
    const response = await service(
      jsonReply(
        { errorCode: '401', errorText: 'Invalid rest api key.', token: null },
        401,
      ),
    ).authorize(minimalPayment);
    expect(response.isSuccess).toBe(false);
    expect(response.status.code).toBe('401');
    expect(response.confirmUrl).toBeUndefined();
  });

  it('a password shorter than 16 bytes is an encryption error', async () => {
    const error = await errorType(
      new WingService({
        merchant: merchant.with({ password: 'too-short' }),
      }).authorize(minimalPayment),
    );
    expect(error?.type).toBe('encryption');
  });

  it('inquiry reads a transaction at the top level', async () => {
    const fetch = jsonReply({
      errorCode: '200',
      respType: 'respType',
      amount: '15.00',
      total_amount: 15.0,
      currency: 'USD',
      order_reference_no: 'c19245baae',
      transaction_id: '0002355252200023',
    });

    const response = await service(fetch).inquiry('c19245baae');

    expect(response.isSuccess).toBe(true);
    expect(response.transaction?.amount).toBe(15);
    expect(response.transaction?.raw['respType']).toBe('respType');
    expect(response.isPaid(15)).toBe(true);
    expect(response.isPaid(15.01)).toBe(false);
    expect(fetch.requests[0]!.url).toBe(
      `https://wing.test/wingonlinesdkv2${INQUIRY_PATH}`,
    );
    expect(await fetch.requests[0]!.json()).toEqual(
      builder().inquiry('c19245baae'),
    );
  });

  it('inquiry reads a transaction inside data', async () => {
    const response = await service(
      jsonReply({
        errorCode: '200',
        data: { amount: 2.5, transaction_id: 'T1' },
      }),
    ).inquiry('x');
    expect(response.transaction?.transactionId).toBe('T1');
    expect(response.isPaid(2.5)).toBe(true);
  });

  it('transaction not found is returned, not thrown', async () => {
    const response = await service(
      jsonReply({
        errorCode: '006035',
        errorText: 'Transaction not found...!',
      }),
    ).inquiry('x');
    expect(response.isSuccess).toBe(false);
    expect(response.status.code).toBe('006035');
    expect(response.transaction).toBeUndefined();
    expect(response.isPaid(1)).toBe(false);
  });

  it('an HTML page is an unexpected, retryable response', async () => {
    const error = await errorType(
      service(fakeFetch(() => new Response('<html>', { status: 502 }))).inquiry(
        'x',
      ),
    );
    expect(error?.type).toBe('unexpectedResponse');
    expect(error?.statusCode).toBe(502);
    expect(error?.isRetryable).toBe(true);
  });

  it('network failures are connection errors', async () => {
    const error = await errorType(
      service(
        fakeFetch(() => {
          throw new TypeError('fetch failed');
        }),
      ).inquiry('x'),
    );
    expect(error?.type).toBe('connection');
    expect(error?.isRetryable).toBe(true);
  });

  it('an aborted call is cancelled', async () => {
    const controller = new AbortController();
    controller.abort();
    const error = await errorType(
      service(jsonReply({ errorCode: '200' })).inquiry('x', {
        signal: controller.signal,
      }),
    );
    expect(error?.type).toBe('cancelled');
  });

  it('a slow reply times out', async () => {
    const slow = fakeFetch(
      (request) =>
        new Promise((_resolve, reject) => {
          request.signal.addEventListener('abort', () => {
            reject(request.signal.reason as Error);
          });
        }),
    );
    const error = await errorType(
      new WingService({ merchant, fetch: slow, timeoutMs: 50 }).inquiry('x'),
    );
    expect(error?.type).toBe('timeout');
  });
});

describe('callbacks', () => {
  const wing = new WingService({ merchant });
  const contents = kat['callback_contents']!;

  it.each([
    ['JSON', JSON.stringify({ contents })],
    ['form', `contents=${encodeURIComponent(contents)}`],
    ['bare', contents],
  ])('a %s body parses', (_kind, body) => {
    const callback = wing.parseCallback(body);
    expect(callback.transactionId).toBe('0002355252200023');
    expect(callback.orderReferenceNo).toBe('1234321');
    expect(callback.amount).toBe(1.5);
    expect(callback.currency).toBe('USD');
    expect(callback.psTrnId).toBe(' ONL015627');
    expect(callback.covers(1.5)).toBe(true);
    expect(callback.covers(1.51)).toBe(false);
  });

  it('contents from another password are rejected', () => {
    const other = new WingService({
      merchant: merchant.with({ password: 'another-password-0123456789' }),
    });
    for (const body of [
      contents,
      'not base64!',
      Buffer.from('short').toString('base64'),
    ]) {
      expect(() => other.parseCallback(body)).toThrow(
        expect.objectContaining({ type: 'invalidCallback' }),
      );
    }
    const list = new NodeWingCrypto().aes256CbcEncrypt(
      '[1]',
      password,
      passwordIv(password),
    );
    expect(() => wing.parseCallback(list)).toThrow(
      expect.objectContaining({ type: 'invalidCallback' }),
    );
  });

  it('numbers sent as strings parse', () => {
    const transaction = transactionFromJson({
      amount: '10.5',
      fee: 0,
      transaction_id: 123,
    });
    expect(transaction.amount).toBe(10.5);
    expect(transaction.fee).toBe(0);
    expect(transaction.transactionId).toBe('123');
  });
});

describe('secrets', () => {
  it('never appear in toString, inspect, JSON or logs', async () => {
    for (const text of [
      String(merchant),
      inspect(merchant),
      JSON.stringify(merchant),
    ]) {
      expect(text).not.toContain('test-rest-api-key');
      expect(text).not.toContain('test-password');
    }
    const lines: string[] = [];
    await new WingService({
      merchant,
      fetch: jsonReply({ errorCode: '006035', errorText: 'x' }),
      logger: (line) => lines.push(line),
    }).inquiry('x');
    expect(lines).toHaveLength(2);
    expect(lines.join('\n')).not.toContain('test-rest-api-key');
  });
});

it('SDK_VERSION matches package.json', () => {
  const pkg = JSON.parse(
    readFileSync(new URL('../package.json', import.meta.url), 'utf8'),
  ) as { version: string };
  expect(SDK_VERSION).toBe(pkg.version);
});
