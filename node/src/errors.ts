/** What went wrong in a {@link WingError}. */
export type WingErrorType =
  /** Wing could not be reached (DNS, refused connection, offline, ...) */
  | 'connection'
  /** the request took longer than the configured timeout */
  | 'timeout'
  /** the call was aborted with its `AbortSignal` */
  | 'cancelled'
  /** Wing's TLS certificate was rejected */
  | 'badCertificate'
  /** Wing answered without an `errorCode` (e.g. an HTML error page) */
  | 'unexpectedResponse'
  /** the payload could not be encrypted (e.g. a password shorter than 16 bytes) */
  | 'encryption'
  /** callback contents do not decrypt with the password, or are not a JSON object */
  | 'invalidCallback'
  /** any other failure; see `cause` */
  | 'unknown';

/**
 * Thrown when Wing could not be reached or did not answer with an
 * `errorCode`, and for invalid local input such as a short password. Branch
 * on {@link type}.
 *
 * Wing business errors (invalid REST API key, transaction not found, ...)
 * are not thrown: they are returned in the response `status`.
 */
export class WingError extends Error {
  override readonly name = 'WingError';

  /** HTTP status code, when a response was received */
  readonly statusCode: number | undefined;

  constructor(
    /** what went wrong */
    readonly type: WingErrorType,
    message: string,
    options: {
      /** HTTP status code, when a response was received */
      statusCode?: number;
      /** the underlying error */
      cause?: unknown;
    } = {},
  ) {
    super(message, { cause: options.cause });
    this.statusCode = options.statusCode;
  }

  /** whether retrying the same call later may succeed */
  get isRetryable(): boolean {
    return (
      this.type === 'connection' ||
      this.type === 'timeout' ||
      (this.type === 'unexpectedResponse' && (this.statusCode ?? 0) >= 500)
    );
  }
}
