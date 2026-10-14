import 'dart:convert';
import 'dart:math';

import '../models/requests/wing_payment.dart';
import '../models/wing_merchant.dart';
import 'wing_crypto.dart';

/// returns the current time; injectable so `timestamp` can be tested
typedef WingClock = DateTime Function();

/// returns a fresh `rand_str`: 16 characters among `0-9` and `a-f`
typedef WingRandom = String Function();

/// Builds the encrypted and hashed request bodies of the Wing online
/// payment APIs.
///
/// - `payload` is `AES-256-CBC(JSON, password, first 16 bytes of password)`
/// - `hash` is `UPPERCASE(SHA256(AES-256-CBC(base64(username#rest_api_key#
///   bill_till_number#amount#order_reference_no#rand_str#timestamp),
///   password, rand_str)))`
///
/// with AES output in base64, as PHP's `openssl_encrypt` returns it.
class WingRequestBuilder {
  /// partner credentials used to encrypt and sign
  final WingMerchant merchant;

  /// source of `timestamp`
  final WingClock clock;

  /// source of `rand_str`
  final WingRandom random;

  /// encryption and hashing
  final WingCrypto crypto;

  /// Creates a builder for [merchant]; [clock] defaults to `DateTime.now`
  /// and [random] to [randomString].
  WingRequestBuilder({
    required this.merchant,
    WingClock? clock,
    WingRandom? random,
    this.crypto = const WingCrypto(),
  }) : clock = clock ?? DateTime.now,
       random = random ?? randomString;

  /// Body of the authorization API: `username`, `rest_api_key`, `payload`,
  /// `hash` and `sandbox`.
  ///
  /// Throws [ArgumentError] for an amount with more than 2 decimals, a
  /// malformed [randStr] or [timestamp], or a password shorter than 16 bytes.
  Map<String, String> authorization(
    WingPayment payment, {
    String? randStr,
    String? timestamp,
  }) {
    final rand = _randStr(randStr);
    final time = _timestamp(timestamp);
    final amount = formatAmount(payment.amount);
    return {
      'username': merchant.username,
      'rest_api_key': merchant.restApiKey,
      'payload': crypto.aes256CbcEncrypt(
        payloadJson(payment, randStr: rand, timestamp: time),
        merchant.password,
        WingCrypto.passwordIv(merchant.password),
      ),
      'hash': hash(
        amount: amount,
        orderReferenceNo: payment.orderReferenceNo,
        randStr: rand,
        timestamp: time,
      ),
      'sandbox': _sandbox,
    };
  }

  /// The payment as the JSON Wing encrypts into `payload`, in the order of
  /// the spec's sample; absent optional fields are left out.
  String payloadJson(
    WingPayment payment, {
    required String randStr,
    required String timestamp,
  }) {
    final fields = <String, String?>{
      'amount': formatAmount(payment.amount),
      'bill_till_number': merchant.billTillNumber,
      'order_reference_no': payment.orderReferenceNo,
      'return_url': payment.returnUrl,
      'cancel_url': payment.cancelUrl,
      'rand_str': randStr,
      'timestamp': timestamp,
      'wing_account': payment.wingAccount,
      'integration_type': payment.integrationType.value,
      'is_wingapp_installed': payment.isWingAppInstalled ? '1' : '0',
      'item_name': payment.itemName,
      'merchant_name': payment.merchantName,
    };
    return json.encode({
      for (final e in fields.entries)
        if (e.value != null) e.key: e.value,
    });
  }

  /// `hash` of an authorization; [amount] as formatted by [formatAmount].
  String hash({
    required String amount,
    required String orderReferenceNo,
    required String randStr,
    required String timestamp,
  }) {
    final plain = [
      merchant.username,
      merchant.restApiKey,
      merchant.billTillNumber,
      amount,
      orderReferenceNo,
      randStr,
      timestamp,
    ].join('#');
    return crypto.sha256Upper(
      crypto.aes256CbcEncrypt(
        base64.encode(utf8.encode(plain)),
        merchant.password,
        utf8.encode(_randStr(randStr)),
      ),
    );
  }

  /// Body of the transaction inquiry API.
  Map<String, String> inquiry(String orderReferenceNo) => {
    'username': merchant.username,
    'rest_api_key': merchant.restApiKey,
    'order_reference_no': orderReferenceNo,
    'sandbox': _sandbox,
  };

  String get _sandbox => merchant.sandbox ? '1' : '0';

  String _randStr(String? randStr) {
    final value = randStr ?? random();
    if (!RegExp(r'^[0-9a-f]{16}$').hasMatch(value)) {
      throw ArgumentError.value(
        value,
        'randStr',
        'must be 16 characters among 0-9 and a-f',
      );
    }
    return value;
  }

  String _timestamp(String? timestamp) {
    final value =
        timestamp ?? (clock().millisecondsSinceEpoch ~/ 1000).toString();
    if (!RegExp(r'^\d+$').hasMatch(value)) {
      throw ArgumentError.value(value, 'timestamp', 'must be Unix seconds');
    }
    return value;
  }

  /// 16 random characters among `0-9` and `a-f`, from a secure source.
  static String randomString() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
  }

  /// [amount] with 2 decimals, as Wing requires (`5.00`, `2.50`,
  /// `12000.00`).
  ///
  /// Throws [ArgumentError] when [amount] is not positive or has more than
  /// 2 decimals: Wing would charge a rounded amount.
  static String formatAmount(num amount) {
    if (!amount.isFinite || amount <= 0 || amount >= 1e13) {
      throw ArgumentError.value(
        amount,
        'amount',
        'must be positive and below 1e13',
      );
    }
    final cents = (amount * 100).round();
    if (cents / 100 != amount) {
      throw ArgumentError.value(
        amount,
        'amount',
        'must have at most 2 decimals',
      );
    }
    return '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';
  }
}
