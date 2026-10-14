import { NodeWingCrypto, passwordIv, type WingCrypto } from './crypto.js';
import { WingError, type WingErrorType } from './errors.js';
import type { WingMerchant } from './merchant.js';
import {
  inquiryResponseFromJson,
  statusFromJson,
  transactionFromJson,
  type AuthorizationResponse,
  type InquiryResponse,
  type Json,
  type Payment,
  type Transaction,
} from './models.js';
import {
  WingRequestBuilder,
  type RequestBody,
  type WingClock,
  type WingRandom,
} from './request-builder.js';
import { SDK_VERSION } from './version.js';

/** receives request/response log lines (the REST API key is masked) */
export type WingLogger = (message: string) => void;

/** Options of every API call. */
export interface CallOptions {
  /** aborts the call; it then throws a `cancelled` {@link WingError} */
  signal?: AbortSignal | undefined;
}

/** Dependencies of {@link WingService}; all but `merchant` are optional. */
export interface WingServiceOptions {
  /** partner credentials used to encrypt and sign */
  merchant: WingMerchant;
  /** HTTP client (default: global `fetch`) */
  fetch?: typeof globalThis.fetch | undefined;
  /** source of `timestamp` (default: current time) */
  clock?: WingClock | undefined;
  /** source of `rand_str` (default: `node:crypto` random bytes) */
  random?: WingRandom | undefined;
  /** AES-256-CBC and SHA-256 (default: `node:crypto`) */
  crypto?: WingCrypto | undefined;
  /** receives request/response logs; nothing is logged without it */
  logger?: WingLogger | undefined;
  /** per request timeout in milliseconds (default 60 000) */
  timeoutMs?: number | undefined;
}

/** endpoint of {@link WingService.authorize} */
export const AUTHORIZATION_PATH = '/v1/online/payment/authorization';
/** Wing's payment page, opened by {@link WingService.confirmUrl} */
export const CONFIRM_PATH = '/v1/online/payment/confirm';
/**
 * endpoint of {@link WingService.inquiry}: `v2`, as in section 4.1 of the
 * spec (v2.0.3) and on Wing's staging server
 */
export const INQUIRY_PATH = '/v2/online/payment/transaction/inquiry';

/**
 * Wing Bank online payment (Web SDK v2) client.
 *
 * Wing business errors (invalid REST API key, transaction not found, ...)
 * are returned in `status`. A {@link WingError} is thrown only when Wing
 * could not be reached or did not answer with an `errorCode`.
 *
 * Run it on your server: the REST API key and the password are secrets.
 */
export class WingService {
  /** partner credentials used to encrypt and sign */
  readonly merchant: WingMerchant;
  /** builds the request bodies; exposed to support new endpoints */
  readonly requestBuilder: WingRequestBuilder;
  readonly #crypto: WingCrypto;
  readonly #fetch: typeof globalThis.fetch;
  readonly #logger: WingLogger | undefined;
  readonly #timeoutMs: number;

  constructor(options: WingServiceOptions) {
    this.merchant = options.merchant;
    this.#crypto = options.crypto ?? new NodeWingCrypto();
    this.requestBuilder = new WingRequestBuilder(options.merchant, {
      clock: options.clock,
      random: options.random,
      crypto: this.#crypto,
    });
    this.#fetch = options.fetch ?? globalThis.fetch;
    this.#logger = options.logger;
    this.#timeoutMs = options.timeoutMs ?? 60_000;
  }

  /**
   * Encrypts and signs `payment` and asks Wing for a payment token. On
   * success, redirect the payer to `confirmUrl`.
   * @throws {RangeError} (rejects) for an amount with more than 2 decimals
   * @throws {WingError} `encryption` (rejects) for a password shorter than 16 bytes
   */
  async authorize(
    payment: Payment,
    options: CallOptions = {},
  ): Promise<AuthorizationResponse> {
    if (Buffer.byteLength(this.merchant.password, 'utf8') < 16) {
      throw new WingError(
        'encryption',
        'The Wing password must be at least 16 bytes: its first 16 are the IV',
      );
    }
    const json = await this.#post(
      AUTHORIZATION_PATH,
      this.requestBuilder.authorization(payment),
      options,
    );
    const status = statusFromJson(json);
    const token = typeof json['token'] === 'string' ? json['token'] : undefined;
    const hasToken = token !== undefined && token !== '';
    return {
      status,
      token,
      confirmUrl: hasToken ? this.confirmUrl(token) : undefined,
      isSuccess: status.code === '200' && hasToken,
    };
  }

  /** Wing's payment page for an authorization `token`: `{base}/v1/online/payment/confirm?token=base64(token)`. */
  confirmUrl(token: string): string {
    return `${this.#url(CONFIRM_PATH)}?token=${encodeURIComponent(Buffer.from(token, 'utf8').toString('base64'))}`;
  }

  /**
   * Details of the payment of `orderReferenceNo`. Call it when Wing
   * redirects to your `return_url` with `status=success`, and check
   * `isPaid(price)` before delivering.
   */
  async inquiry(
    orderReferenceNo: string,
    options: CallOptions = {},
  ): Promise<InquiryResponse> {
    return inquiryResponseFromJson(
      await this.#post(
        INQUIRY_PATH,
        this.requestBuilder.inquiry(orderReferenceNo),
        options,
      ),
    );
  }

  /**
   * The JSON in the `contents` Wing POSTs to your callback URL, decrypted
   * with the merchant password.
   * @throws {WingError} `invalidCallback` when it was not encrypted with the password
   */
  decryptCallback(contents: string): string {
    try {
      return this.#crypto.aes256CbcDecrypt(
        contents,
        this.merchant.password,
        passwordIv(this.merchant.password),
      );
    } catch (error) {
      throw new WingError(
        'invalidCallback',
        'Callback contents could not be decrypted with the Wing password',
        { cause: error },
      );
    }
  }

  /**
   * Decrypts and parses the raw body Wing POSTed to your callback URL: the
   * JSON `{"contents": "..."}`, the form `contents=...`, or the value
   * itself. Still confirm with {@link inquiry} and the amount before
   * delivering.
   *
   * ```ts
   * app.post('/wing/callback', express.text({ type: '*\/*' }), (req, res) => {
   *   const transaction = wing.parseCallback(req.body);
   * });
   * ```
   * @throws {WingError} `invalidCallback`
   */
  parseCallback(body: string): Transaction {
    const decrypted = this.decryptCallback(callbackContents(body));
    let decoded: unknown;
    try {
      decoded = JSON.parse(decrypted);
    } catch (error) {
      throw new WingError('invalidCallback', 'Decrypted callback is not JSON', {
        cause: error,
      });
    }
    if (!isObject(decoded)) {
      throw new WingError(
        'invalidCallback',
        'Decrypted callback is not a JSON object',
      );
    }
    return transactionFromJson(decoded);
  }

  /**
   * POSTs JSON and returns Wing's reply. Wing answers errors with a JSON
   * body carrying `errorCode`, possibly with a non-2xx HTTP status, which is
   * returned like a success.
   */
  async #post(
    path: string,
    body: RequestBody,
    options: CallOptions,
  ): Promise<Json> {
    const url = this.#url(path);
    this.#logger?.(
      `[Wing] POST ${url} ${JSON.stringify({ ...body, rest_api_key: '***' })}`,
    );

    const timeout = AbortSignal.timeout(this.#timeoutMs);
    const signal = options.signal
      ? AbortSignal.any([options.signal, timeout])
      : timeout;

    const headers: Record<string, string> = {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      'User-Agent': `node-wing/${SDK_VERSION}`,
    };
    if (this.merchant.referer !== '') {
      headers['Referer'] = Buffer.from(this.merchant.referer, 'utf8').toString(
        'base64',
      );
    }

    let status: number;
    let text: string;
    try {
      const response = await this.#fetch(url, {
        method: 'POST',
        headers,
        body: JSON.stringify(body),
        signal,
      });
      status = response.status;
      text = await response.text();
    } catch (error) {
      this.#logger?.(`[Wing] failed ${String(error)}`);
      const [type, message] = describe(error, options.signal, timeout);
      throw new WingError(type, message, { cause: error });
    }

    this.#logger?.(`[Wing] ${String(status)} ${text}`);
    const json = errorCodeBody(text);
    if (json !== undefined) return json;
    throw new WingError('unexpectedResponse', 'Unexpected response from Wing', {
      statusCode: status,
    });
  }

  #url(path: string): string {
    return this.merchant.baseUrl.replace(/\/+$/, '') + path;
  }
}

/** The encrypted `contents` of a callback body (see {@link WingService.parseCallback}). */
export function callbackContents(body: string): string {
  const trimmed = body.trim();
  if (trimmed.startsWith('{')) {
    try {
      const decoded: unknown = JSON.parse(trimmed);
      if (isObject(decoded) && typeof decoded['contents'] === 'string') {
        return decoded['contents'];
      }
    } catch {
      // not JSON: fall through
    }
  }
  if (trimmed.startsWith('contents=')) {
    return new URLSearchParams(trimmed).get('contents') ?? '';
  }
  return trimmed;
}

const isObject = (value: unknown): value is Json =>
  value !== null && typeof value === 'object' && !Array.isArray(value);

/** decode `text` when it is a JSON object with Wing's `errorCode` */
function errorCodeBody(text: string): Json | undefined {
  let json: unknown;
  try {
    json = JSON.parse(text);
  } catch {
    return undefined;
  }
  return isObject(json) && 'errorCode' in json ? json : undefined;
}

const CERTIFICATE_ERRORS = new Set([
  'CERT_HAS_EXPIRED',
  'DEPTH_ZERO_SELF_SIGNED_CERT',
  'SELF_SIGNED_CERT_IN_CHAIN',
  'UNABLE_TO_VERIFY_LEAF_SIGNATURE',
  'UNABLE_TO_GET_ISSUER_CERT_LOCALLY',
  'ERR_TLS_CERT_ALTNAME_INVALID',
]);

function describe(
  error: unknown,
  userSignal: AbortSignal | undefined,
  timeout: AbortSignal,
): [WingErrorType, string] {
  if (userSignal?.aborted) {
    return ['cancelled', 'Request to Wing was cancelled'];
  }
  if (timeout.aborted) return ['timeout', 'Timeout with Wing'];
  const cause = (error as { cause?: { code?: unknown } } | null)?.cause;
  const code = typeof cause?.code === 'string' ? cause.code : undefined;
  if (code !== undefined && CERTIFICATE_ERRORS.has(code)) {
    return ['badCertificate', 'Bad certificate from Wing'];
  }
  if (error instanceof TypeError) {
    return ['connection', 'Could not connect to Wing'];
  }
  return ['unknown', `Request to Wing failed: ${String(error)}`];
}
