import { randomBytes } from 'node:crypto';

import { NodeWingCrypto, passwordIv, type WingCrypto } from './crypto.js';
import type { WingMerchant } from './merchant.js';
import type { Payment } from './models.js';

/** returns the current time; injectable so `timestamp` can be tested */
export type WingClock = () => Date;

/** returns a fresh `rand_str`: 16 characters among `0-9` and `a-f` */
export type WingRandom = () => string;

/** A request body: every value is a string. */
export type RequestBody = Record<string, string>;

/**
 * Builds the encrypted and hashed request bodies of the Wing online payment
 * APIs:
 *
 * - `payload` is `AES-256-CBC(JSON, password, first 16 bytes of password)`
 * - `hash` is `UPPERCASE(SHA256(AES-256-CBC(base64(username#rest_api_key#
 *   bill_till_number#amount#order_reference_no#rand_str#timestamp), password, rand_str)))`
 *
 * with AES output in base64, as PHP's `openssl_encrypt` returns it.
 */
export class WingRequestBuilder {
  readonly #merchant: WingMerchant;
  readonly #clock: WingClock;
  readonly #random: WingRandom;
  readonly #crypto: WingCrypto;

  constructor(
    merchant: WingMerchant,
    options: {
      clock?: WingClock | undefined;
      random?: WingRandom | undefined;
      crypto?: WingCrypto | undefined;
    } = {},
  ) {
    this.#merchant = merchant;
    this.#clock = options.clock ?? (() => new Date());
    this.#random = options.random ?? randomString;
    this.#crypto = options.crypto ?? new NodeWingCrypto();
  }

  /**
   * Body of the authorization API: `username`, `rest_api_key`, `payload`,
   * `hash` and `sandbox`.
   * @throws {RangeError} for an amount with more than 2 decimals, a malformed
   *   `randStr` or `timestamp`, or a password shorter than 16 bytes
   */
  authorization(
    payment: Payment,
    options: { randStr?: string; timestamp?: string } = {},
  ): RequestBody {
    const randStr = this.#randStr(options.randStr);
    const timestamp = this.#timestamp(options.timestamp);
    const m = this.#merchant;
    return {
      username: m.username,
      rest_api_key: m.restApiKey,
      payload: this.#crypto.aes256CbcEncrypt(
        this.payloadJson(payment, randStr, timestamp),
        m.password,
        passwordIv(m.password),
      ),
      hash: this.hash(
        formatAmount(payment.amount),
        payment.orderReferenceNo,
        randStr,
        timestamp,
      ),
      sandbox: this.#sandbox,
    };
  }

  /** The JSON encrypted into `payload`, in the order of the spec's sample; absent optional fields are left out. */
  payloadJson(payment: Payment, randStr: string, timestamp: string): string {
    const fields: Record<string, string | undefined> = {
      amount: formatAmount(payment.amount),
      bill_till_number: this.#merchant.billTillNumber,
      order_reference_no: payment.orderReferenceNo,
      return_url: payment.returnUrl,
      cancel_url: payment.cancelUrl,
      rand_str: randStr,
      timestamp,
      wing_account: payment.wingAccount,
      integration_type: payment.integrationType ?? 'WEBAPP',
      is_wingapp_installed: payment.isWingAppInstalled ? '1' : '0',
      item_name: payment.itemName,
      merchant_name: payment.merchantName,
    };
    return JSON.stringify(fields);
  }

  /** `hash` of an authorization; `amount` as formatted by {@link formatAmount}. */
  hash(
    amount: string,
    orderReferenceNo: string,
    randStr: string,
    timestamp: string,
  ): string {
    const m = this.#merchant;
    const plain = [
      m.username,
      m.restApiKey,
      m.billTillNumber,
      amount,
      orderReferenceNo,
      randStr,
      timestamp,
    ].join('#');
    return this.#crypto.sha256Upper(
      this.#crypto.aes256CbcEncrypt(
        Buffer.from(plain, 'utf8').toString('base64'),
        m.password,
        Buffer.from(this.#randStr(randStr), 'utf8'),
      ),
    );
  }

  /** Body of the transaction inquiry API. */
  inquiry(orderReferenceNo: string): RequestBody {
    return {
      username: this.#merchant.username,
      rest_api_key: this.#merchant.restApiKey,
      order_reference_no: orderReferenceNo,
      sandbox: this.#sandbox,
    };
  }

  get #sandbox(): string {
    return this.#merchant.sandbox ? '1' : '0';
  }

  #randStr(randStr: string | undefined): string {
    const value = randStr ?? this.#random();
    if (!/^[0-9a-f]{16}$/.test(value)) {
      throw new RangeError(
        `rand_str must be 16 characters among 0-9 and a-f, got "${value}"`,
      );
    }
    return value;
  }

  #timestamp(timestamp: string | undefined): string {
    const value =
      timestamp ?? String(Math.floor(this.#clock().getTime() / 1000));
    if (!/^\d+$/.test(value)) {
      throw new RangeError(`timestamp must be Unix seconds, got "${value}"`);
    }
    return value;
  }
}

/** 16 random characters among `0-9` and `a-f`, from a secure source. */
export function randomString(): string {
  return randomBytes(8).toString('hex');
}

/**
 * `amount` with 2 decimals, as Wing requires (`5.00`, `2.50`, `12000.00`).
 * @throws {RangeError} when it is not positive or has more than 2 decimals:
 *   Wing would charge a rounded amount
 */
export function formatAmount(amount: number): string {
  if (!Number.isFinite(amount) || amount <= 0 || amount >= 1e13) {
    throw new RangeError(
      `amount must be positive and below 1e13, got ${String(amount)}`,
    );
  }
  const cents = Math.round(amount * 100);
  if (cents / 100 !== amount) {
    throw new RangeError(
      `amount must have at most 2 decimals, got ${String(amount)}`,
    );
  }
  return `${String(Math.trunc(cents / 100))}.${String(cents % 100).padStart(2, '0')}`;
}
