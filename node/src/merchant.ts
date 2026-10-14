/** Options of {@link WingMerchant}. */
export interface WingMerchantOptions {
  /** username provided by Wing */
  username: string;
  /** REST API key provided by Wing (`rest_api_key`, secret) */
  restApiKey: string;
  /** password provided by Wing: the AES-256 key; its first 16 bytes are the payload IV (secret) */
  password: string;
  /** biller code or till number provided by Wing (`bill_till_number`) */
  billTillNumber: string;
  /** domain registered with Wing, sent Base64-encoded as the `Referer` header */
  referer: string;
  /** {@link WingMerchant.UAT_URL} (default), or the production URL Wing gave you */
  baseUrl?: string | undefined;
  /** sends `sandbox: "1"` (testing, default) when true, `"0"` (production) when false */
  sandbox?: boolean | undefined;
}

const inspectCustom = Symbol.for('nodejs.util.inspect.custom');

/**
 * Partner credentials provided by Wing Bank.
 *
 * The REST API key and the password are secrets: readable as `restApiKey`
 * and `password` but kept out of `toString()`, `util.inspect()` /
 * `console.log()` and `JSON.stringify()`.
 */
export class WingMerchant {
  /** Wing online payment UAT (testing) environment; Wing gives the production URL */
  static readonly UAT_URL = 'https://sdk-uat.wingmoney.com/wingonlinesdkv2';

  /** username provided by Wing */
  readonly username: string;
  /** biller code or till number provided by Wing */
  readonly billTillNumber: string;
  /** domain registered with Wing, sent Base64-encoded as the `Referer` header */
  readonly referer: string;
  /** {@link UAT_URL} or the production URL */
  readonly baseUrl: string;
  /** whether requests are sent with `sandbox: "1"` */
  readonly sandbox: boolean;
  readonly #restApiKey: string;
  readonly #password: string;

  constructor(options: WingMerchantOptions) {
    this.username = options.username;
    this.#restApiKey = options.restApiKey;
    this.#password = options.password;
    this.billTillNumber = options.billTillNumber;
    this.referer = options.referer;
    this.baseUrl = options.baseUrl ?? WingMerchant.UAT_URL;
    this.sandbox = options.sandbox ?? true;
  }

  /** REST API key provided by Wing (secret) */
  get restApiKey(): string {
    return this.#restApiKey;
  }

  /** password provided by Wing (secret) */
  get password(): string {
    return this.#password;
  }

  /** a copy with the given fields replaced */
  with(changes: Partial<WingMerchantOptions>): WingMerchant {
    return new WingMerchant({
      username: this.username,
      restApiKey: this.#restApiKey,
      password: this.#password,
      billTillNumber: this.billTillNumber,
      referer: this.referer,
      baseUrl: this.baseUrl,
      sandbox: this.sandbox,
      ...changes,
    });
  }

  /** the fields without the secrets, for logs */
  toJSON(): Record<string, string | boolean> {
    return {
      username: this.username,
      restApiKey: '***',
      password: '***',
      billTillNumber: this.billTillNumber,
      referer: this.referer,
      baseUrl: this.baseUrl,
      sandbox: this.sandbox,
    };
  }

  toString(): string {
    return `WingMerchant(username: ${this.username}, restApiKey: ***, password: ***, billTillNumber: ${this.billTillNumber}, referer: ${this.referer}, baseUrl: ${this.baseUrl}, sandbox: ${String(this.sandbox)})`;
  }

  [inspectCustom](): string {
    return this.toString();
  }
}
