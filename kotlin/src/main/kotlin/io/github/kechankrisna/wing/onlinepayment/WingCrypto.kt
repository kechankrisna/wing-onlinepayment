package io.github.kechankrisna.wing.onlinepayment

import java.nio.ByteBuffer
import java.nio.charset.CharacterCodingException
import java.nio.charset.CodingErrorAction
import java.security.GeneralSecurityException
import java.security.MessageDigest
import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * Encryption and hashing of Wing's Web SDK spec. Implement it to plug in
 * another backend (an HSM, a KMS, ...); the default is [DefaultWingCrypto].
 */
public interface WingCrypto {
    /**
     * PHP's `openssl_encrypt(plainText, 'AES-256-CBC', password, 0, iv)`: the
     * UTF-8 password NUL-padded or truncated to 32 bytes, a 16-byte IV,
     * PKCS#7 padding, base64 output.
     *
     * @throws IllegalArgumentException when [iv] is not 16 bytes
     */
    public fun aes256CbcEncrypt(
        plainText: String,
        password: String,
        iv: ByteArray,
    ): String

    /**
     * Decrypts what [aes256CbcEncrypt] returns.
     *
     * @throws IllegalArgumentException when it was not encrypted with this
     *   password and IV, or [iv] is not 16 bytes
     */
    public fun aes256CbcDecrypt(
        base64CipherText: String,
        password: String,
        iv: ByteArray,
    ): String

    /** Uppercase hex SHA-256 of [message] (UTF-8). */
    public fun sha256Upper(message: String): String
}

/** Default [WingCrypto], backed by `javax.crypto`. */
public object DefaultWingCrypto : WingCrypto {
    private const val KEY_BYTES = 32
    private const val IV_BYTES = 16

    override fun aes256CbcEncrypt(
        plainText: String,
        password: String,
        iv: ByteArray,
    ): String = Base64.getEncoder().encodeToString(cipher(Cipher.ENCRYPT_MODE, password, iv).doFinal(plainText.toByteArray(Charsets.UTF_8)))

    override fun aes256CbcDecrypt(
        base64CipherText: String,
        password: String,
        iv: ByteArray,
    ): String {
        val cipher = cipher(Cipher.DECRYPT_MODE, password, iv)
        try {
            val plain = cipher.doFinal(Base64.getDecoder().decode(base64CipherText.trim()))
            return Charsets.UTF_8
                .newDecoder()
                .onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT)
                .decode(ByteBuffer.wrap(plain))
                .toString()
        } catch (e: IllegalArgumentException) {
            throw IllegalArgumentException("not base64", e)
        } catch (e: GeneralSecurityException) {
            throw IllegalArgumentException("not encrypted with this password", e)
        } catch (e: CharacterCodingException) {
            throw IllegalArgumentException("not encrypted with this password", e)
        }
    }

    override fun sha256Upper(message: String): String =
        MessageDigest
            .getInstance("SHA-256")
            .digest(message.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02X".format(it) }

    /**
     * The first 16 bytes of [password], the IV of the payload and the callback.
     *
     * @throws IllegalArgumentException for a shorter password
     */
    public fun passwordIv(password: String): ByteArray {
        val bytes = password.toByteArray(Charsets.UTF_8)
        require(bytes.size >= IV_BYTES) { "the Wing password must be at least 16 bytes: its first 16 are the IV" }
        return bytes.copyOf(IV_BYTES)
    }

    private fun cipher(
        mode: Int,
        password: String,
        iv: ByteArray,
    ): Cipher {
        require(iv.size == IV_BYTES) { "the IV must be 16 bytes, got ${iv.size}" }
        val key = password.toByteArray(Charsets.UTF_8).copyOf(KEY_BYTES)
        return Cipher.getInstance("AES/CBC/PKCS5Padding").apply {
            init(mode, SecretKeySpec(key, "AES"), IvParameterSpec(iv))
        }
    }
}
