import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:pointycastle/export.dart';

/// Encryption and hashing matching PHP's
/// `openssl_encrypt($data, 'AES-256-CBC', $key, 0, $iv)`, the function of
/// the PHP sample in Wing's Web SDK spec: the key is the UTF-8 password,
/// NUL-padded or truncated to 32 bytes; the IV is 16 bytes; PKCS#7 padding;
/// base64 output.
///
/// Implement this class to plug in another crypto backend.
class WingCrypto {
  /// Creates the default implementation.
  const WingCrypto();

  /// AES-256-CBC encryption of [plainText] with [password] and [iv], base64.
  ///
  /// Throws [ArgumentError] when [iv] is not 16 bytes.
  String aes256CbcEncrypt(String plainText, String password, List<int> iv) {
    final cipher = _cipher(true, password, iv);
    return base64.encode(cipher.process(utf8.encode(plainText)));
  }

  /// Decrypts what [aes256CbcEncrypt] returns.
  ///
  /// Throws [FormatException] when [base64CipherText] is not base64 or was
  /// not encrypted with this key and IV (bad padding or UTF-8), and
  /// [ArgumentError] when [iv] is not 16 bytes.
  String aes256CbcDecrypt(
    String base64CipherText,
    String password,
    List<int> iv,
  ) {
    final cipher = _cipher(false, password, iv);
    final Uint8List plain;
    try {
      plain = cipher.process(base64.decode(base64CipherText.trim()));
    } on ArgumentError catch (error) {
      throw FormatException('Not encrypted with this password: $error');
    } on StateError catch (error) {
      throw FormatException('Not encrypted with this password: $error');
    }
    return utf8.decode(plain);
  }

  /// Uppercase hex SHA-256 of [message] (UTF-8).
  String sha256Upper(String message) =>
      crypto.sha256.convert(utf8.encode(message)).toString().toUpperCase();

  /// The first 16 bytes of [password], the IV of the payload and the
  /// callback. Throws [ArgumentError] for a shorter password.
  static Uint8List passwordIv(String password) {
    final bytes = utf8.encode(password);
    if (bytes.length < 16) {
      throw ArgumentError.value(
        '***',
        'password',
        'must be at least 16 bytes: its first 16 are the IV',
      );
    }
    return Uint8List.sublistView(bytes, 0, 16);
  }

  static PaddedBlockCipher _cipher(
    bool encrypt,
    String password,
    List<int> iv,
  ) {
    if (iv.length != 16) {
      throw ArgumentError.value(iv.length, 'iv', 'must be 16 bytes');
    }
    final ivBytes = Uint8List.fromList(iv);
    final passwordBytes = utf8.encode(password);
    final key = Uint8List(32)
      ..setRange(0, min(32, passwordBytes.length), passwordBytes);
    return PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
      ..init(
        encrypt,
        PaddedBlockCipherParameters<CipherParameters, CipherParameters>(
          ParametersWithIV<KeyParameter>(KeyParameter(key), ivBytes),
          null,
        ),
      );
  }
}
