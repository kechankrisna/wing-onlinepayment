// Payloads, hashes and callbacks must equal the known answers in
// spec/test-vectors, computed with PHP's openssl_encrypt as in Wing's spec.
import { describe, expect, it } from 'vitest';

import { WingRequestBuilder, WingService } from '../src/index.js';
import {
  builder,
  fullPayment,
  kat,
  merchant,
  minimalPayment,
  randStr,
  timestamp,
} from './helpers.js';

describe('known answers', () => {
  it('payload with the required fields only', () => {
    expect(builder().payloadJson(minimalPayment, randStr, timestamp)).toBe(
      kat['payload_minimal_json'],
    );
    expect(Object.entries(builder().authorization(minimalPayment))).toEqual([
      ['username', 'online.testing'],
      ['rest_api_key', 'test-rest-api-key'],
      ['payload', kat['payload_minimal']],
      ['hash', kat['hash']],
      ['sandbox', '1'],
    ]);
  });

  it('payload with every field', () => {
    expect(builder().payloadJson(fullPayment, randStr, timestamp)).toBe(
      kat['payload_full_json'],
    );
    expect(builder().authorization(fullPayment)['payload']).toBe(
      kat['payload_full'],
    );
  });

  it('explicit rand_str and timestamp give the same body', () => {
    const body = new WingRequestBuilder(merchant).authorization(
      minimalPayment,
      { randStr, timestamp },
    );
    expect(body['payload']).toBe(kat['payload_minimal']);
    expect(body['hash']).toBe(kat['hash']);
  });

  it('hash of a KHR amount', () => {
    expect(builder().hash('12000.00', 'c19245baae', randStr, timestamp)).toBe(
      kat['hash_khr'],
    );
  });

  it('short and long passwords are padded and truncated like openssl_encrypt', () => {
    const short = builder(
      merchant.with({ password: kat['short_password']! }),
    ).authorization(minimalPayment);
    expect(short['payload']).toBe(kat['payload_minimal_short_password']);
    expect(short['hash']).toBe(kat['hash_short_password']);
    const long = builder(
      merchant.with({ password: kat['long_password']! }),
    ).authorization(minimalPayment);
    expect(long['payload']).toBe(kat['payload_minimal_long_password']);
  });

  it('callback contents', () => {
    expect(
      new WingService({ merchant }).decryptCallback(kat['callback_contents']!),
    ).toBe(kat['callback_json']);
  });
});
