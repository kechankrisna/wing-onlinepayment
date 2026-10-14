import 'package:flutter_wing_checkout/flutter_wing_checkout.dart';

/// Wing credentials compiled in with `--dart-define-from-file=.env`.
///
/// Demo only: a real app must not contain these secrets. Your server keeps
/// them and authorizes payments (see `PaymentBackend`).
abstract final class WingConfig {
  static const apiUrl = String.fromEnvironment('WING_API_URL');
  static const username = String.fromEnvironment('WING_USERNAME');
  static const restApiKey = String.fromEnvironment('WING_REST_API_KEY');
  static const password = String.fromEnvironment('WING_PASSWORD');
  static const billTillNumber = String.fromEnvironment('WING_BILL_TILL_NUMBER');
  static const referer = String.fromEnvironment('WING_REFERER_DOMAIN');
  static const sandbox = String.fromEnvironment('WING_SANDBOX') != '0';

  /// the `.env` keys that are missing or empty
  static List<String> get missing => [
    if (username.isEmpty) 'WING_USERNAME',
    if (restApiKey.isEmpty) 'WING_REST_API_KEY',
    if (password.isEmpty) 'WING_PASSWORD',
    if (billTillNumber.isEmpty) 'WING_BILL_TILL_NUMBER',
    if (referer.isEmpty) 'WING_REFERER_DOMAIN',
  ];

  /// the partner credentials of the `.env`
  static WingMerchant merchant() => WingMerchant(
    username: username,
    restApiKey: restApiKey,
    password: password,
    billTillNumber: billTillNumber,
    referer: referer,
    baseApiUrl: apiUrl.isEmpty ? WingMerchant.uatBaseUrl : apiUrl,
    sandbox: sandbox,
  );
}
