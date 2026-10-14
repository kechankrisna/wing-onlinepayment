import 'wing_status.dart';
import 'wing_transaction.dart';

/// Response of the authorization API.
class WingAuthorizationResponse {
  /// `errorCode` / `errorText`
  final WingStatus status;

  /// authorization token (opaque), when [isSuccess]
  final String? token;

  /// Wing's payment page for [token]: redirect the payer, or open it in a
  /// web view; `null` without a token
  final Uri? confirmUrl;

  /// Creates a [WingAuthorizationResponse].
  const WingAuthorizationResponse({
    required this.status,
    this.token,
    this.confirmUrl,
  });

  /// Whether Wing authorized the payment.
  bool get isSuccess => status.isSuccess && (token?.isNotEmpty ?? false);

  @override
  String toString() =>
      'WingAuthorizationResponse(status: $status, confirmUrl: $confirmUrl)';
}

/// Response of the transaction inquiry API.
class WingInquiryResponse {
  /// `errorCode` / `errorText`
  final WingStatus status;

  /// the transaction, when [isSuccess]
  final WingTransaction? transaction;

  /// Creates a [WingInquiryResponse].
  const WingInquiryResponse({required this.status, this.transaction});

  /// Whether Wing found the transaction.
  bool get isSuccess => status.isSuccess && transaction != null;

  /// Whether the transaction was found and its amount is at least [price]:
  /// Wing asks partners to reject smaller amounts.
  bool isPaid(num price) => isSuccess && transaction!.covers(price);

  /// Parses Wing JSON: the transaction fields are at the top level, or
  /// inside `data`.
  factory WingInquiryResponse.fromJson(Map<String, dynamic> json) {
    final status = WingStatus.fromJson(json);
    if (!status.isSuccess) return WingInquiryResponse(status: status);
    final data = json['data'];
    return WingInquiryResponse(
      status: status,
      transaction: WingTransaction.fromJson(
        data is Map<String, dynamic> ? data : json,
      ),
    );
  }

  @override
  String toString() =>
      'WingInquiryResponse(status: $status, transaction: $transaction)';
}
