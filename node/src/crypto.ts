import { createCipheriv, createDecipheriv, createHash } from 'node:crypto';

/**
 * Encryption and hashing of Wing's Web SDK spec, matching PHP's
 * `openssl_encrypt($data, 'AES-256-CBC', $password, 0, $iv)` from the spec's
 * PHP sample. Implement this interface to plug in another backend.
 */
export interface WingCrypto {
  /** AES-256-CBC of `plainText` with the password and a 16-byte IV, base64 */
  aes256CbcEncrypt(plainText: string, password: string, iv: Uint8Array): string;
  /**
   * Decrypts what {@link aes256CbcEncrypt} returns.
   * @throws {TypeError} when it was not encrypted with this password and IV
   */
  aes256CbcDecrypt(
    base64CipherText: string,
    password: string,
    iv: Uint8Array,
  ): string;
  /** uppercase hex SHA-256 of `message` (UTF-8) */
  sha256Upper(message: string): string;
}

const KEY_BYTES = 32;
const IV_BYTES = 16;

/** Default {@link WingCrypto}, backed by `node:crypto`. */
export class NodeWingCrypto implements WingCrypto {
  aes256CbcEncrypt(
    plainText: string,
    password: string,
    iv: Uint8Array,
  ): string {
    const cipher = createCipheriv('aes-256-cbc', key(password), checkIv(iv));
    return Buffer.concat([
      cipher.update(plainText, 'utf8'),
      cipher.final(),
    ]).toString('base64');
  }

  aes256CbcDecrypt(
    base64CipherText: string,
    password: string,
    iv: Uint8Array,
  ): string {
    const decipher = createDecipheriv(
      'aes-256-cbc',
      key(password),
      checkIv(iv),
    );
    const text = base64CipherText.trim();
    if (!/^[A-Za-z0-9+/]*={0,2}$/.test(text)) {
      throw new TypeError('not base64');
    }
    let plain: Buffer;
    try {
      plain = Buffer.concat([
        decipher.update(Buffer.from(text, 'base64')),
        decipher.final(),
      ]);
    } catch (error) {
      throw new TypeError('not encrypted with this password', {
        cause: error,
      });
    }
    try {
      return new TextDecoder('utf-8', { fatal: true }).decode(plain);
    } catch (error) {
      throw new TypeError('not encrypted with this password', {
        cause: error,
      });
    }
  }

  sha256Upper(message: string): string {
    return createHash('sha256')
      .update(message, 'utf8')
      .digest('hex')
      .toUpperCase();
  }
}

/**
 * The first 16 bytes of `password`, the IV of the payload and the callback.
 * @throws {RangeError} for a shorter password
 */
export function passwordIv(password: string): Buffer {
  const bytes = Buffer.from(password, 'utf8');
  if (bytes.length < IV_BYTES) {
    throw new RangeError(
      'the Wing password must be at least 16 bytes: its first 16 are the IV',
    );
  }
  return bytes.subarray(0, IV_BYTES);
}

/** the UTF-8 password NUL-padded or truncated to 32 bytes, as PHP's openssl_encrypt does */
function key(password: string): Buffer {
  const key = Buffer.alloc(KEY_BYTES);
  Buffer.from(password, 'utf8').copy(key, 0, 0, KEY_BYTES);
  return key;
}

function checkIv(iv: Uint8Array): Uint8Array {
  if (iv.length !== IV_BYTES) {
    throw new RangeError(`the IV must be 16 bytes, got ${String(iv.length)}`);
  }
  return iv;
}
