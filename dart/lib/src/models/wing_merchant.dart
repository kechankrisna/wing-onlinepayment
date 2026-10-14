import 'package:json_annotation/json_annotation.dart';

part 'wing_merchant.g.dart';

/// Partner credentials provided by Wing Bank.
///
/// ```dart
/// final merchant = WingMerchant(
///   username: 'online.yourshop',
///   restApiKey: 'your REST API key',
///   password: 'your encryption password',
///   billTillNumber: 'your biller code or till number',
///   referer: 'https://your-registered-domain.com',
///   baseApiUrl: WingMerchant.uatBaseUrl,
///   sandbox: true,
/// );
/// ```
///
/// [fromJson] / [toJson] use the field names as keys, for loading this
/// configuration from your own secret store. [toJson] contains the secrets.
@JsonSerializable()
class WingMerchant {
  /// Wing online payment UAT (testing) environment. Wing gives the
  /// production URL with the production credentials.
  static const String uatBaseUrl =
      'https://sdk-uat.wingmoney.com/wingonlinesdkv2';

  /// username provided by Wing (`username`)
  final String username;

  /// REST API key provided by Wing (`rest_api_key`, secret)
  final String restApiKey;

  /// password provided by Wing: the AES-256 key of the payload, the hash and
  /// the callback (secret); its first 16 bytes are the payload's IV
  final String password;

  /// biller code or till number provided by Wing (`bill_till_number`)
  final String billTillNumber;

  /// domain registered with Wing, sent Base64-encoded as the `Referer`
  /// header
  final String referer;

  /// [uatBaseUrl], or the production URL Wing gave you
  final String baseApiUrl;

  /// sends `sandbox: "1"` (testing) when true, `"0"` (production) when false
  final bool sandbox;

  /// Creates a [WingMerchant].
  const WingMerchant({
    required this.username,
    required this.restApiKey,
    required this.password,
    required this.billTillNumber,
    required this.referer,
    this.baseApiUrl = WingMerchant.uatBaseUrl,
    this.sandbox = true,
  });

  /// Reads a configuration written by [toJson].
  factory WingMerchant.fromJson(Map<String, dynamic> json) =>
      _$WingMerchantFromJson(json);

  /// JSON keyed by field name; contains the secrets.
  Map<String, dynamic> toJson() => _$WingMerchantToJson(this);

  /// Returns a copy with the given fields replaced.
  WingMerchant copyWith({
    String? username,
    String? restApiKey,
    String? password,
    String? billTillNumber,
    String? referer,
    String? baseApiUrl,
    bool? sandbox,
  }) {
    return WingMerchant(
      username: username ?? this.username,
      restApiKey: restApiKey ?? this.restApiKey,
      password: password ?? this.password,
      billTillNumber: billTillNumber ?? this.billTillNumber,
      referer: referer ?? this.referer,
      baseApiUrl: baseApiUrl ?? this.baseApiUrl,
      sandbox: sandbox ?? this.sandbox,
    );
  }

  /// the REST API key and password are secrets, keep them out of logs
  @override
  String toString() =>
      'WingMerchant(username: $username, restApiKey: ***, password: ***, '
      'billTillNumber: $billTillNumber, referer: $referer, '
      'baseApiUrl: $baseApiUrl, sandbox: $sandbox)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WingMerchant &&
          other.username == username &&
          other.restApiKey == restApiKey &&
          other.password == password &&
          other.billTillNumber == billTillNumber &&
          other.referer == referer &&
          other.baseApiUrl == baseApiUrl &&
          other.sandbox == sandbox;

  @override
  int get hashCode => Object.hash(
    username,
    restApiKey,
    password,
    billTillNumber,
    referer,
    baseApiUrl,
    sandbox,
  );
}
