import 'package:json_annotation/json_annotation.dart';

import '../json_converters.dart';

part 'wing_transaction.g.dart';

/// A Wing payment, as returned by the inquiry API and pushed to your
/// callback URL.
///
/// Wing asks partners to accept only payments whose [amount] is at least
/// the price: check [covers] before delivering.
@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class WingTransaction {
  /// amount the partner requested
  @JsonKey(fromJson: doubleFromJson)
  final double amount;

  /// total amount of the transaction, which can include a fee or an
  /// exchange rate
  @JsonKey(fromJson: nullableDoubleFromJson)
  final double? totalAmount;

  /// `USD` or `KHR`
  @JsonKey(fromJson: nullableStringFromJson)
  final String? currency;

  /// your `order_reference_no`
  @JsonKey(fromJson: stringFromJson)
  final String orderReferenceNo;

  /// Wing transaction id; show it on your success page
  @JsonKey(fromJson: stringFromJson)
  final String transactionId;

  /// remark
  @JsonKey(fromJson: nullableStringFromJson)
  final String? remark;

  /// payer name
  @JsonKey(fromJson: nullableStringFromJson)
  final String? customerName;

  /// fee charged
  @JsonKey(fromJson: nullableDoubleFromJson)
  final double? fee;

  /// currency of [fee]
  @JsonKey(fromJson: nullableStringFromJson)
  final String? feeCurrency;

  /// payer Wing account
  @JsonKey(fromJson: nullableStringFromJson)
  final String? wingAccount;

  /// Wing `ps_trn_id`
  @JsonKey(fromJson: nullableStringFromJson)
  final String? psTrnId;

  /// Wing `fc_trn_id`
  @JsonKey(fromJson: nullableStringFromJson)
  final String? fcTrnId;

  /// merchant wallet identifier
  @JsonKey(fromJson: nullableStringFromJson)
  final String? billerName;

  /// transaction date as Wing sends it, e.g. `28-08-23 09:34:38`
  @JsonKey(fromJson: nullableStringFromJson)
  final String? transactionDate;

  /// every field Wing sent, including ones this class does not model
  @JsonKey(
    readValue: _wholeObject,
    fromJson: _rawFromJson,
    includeToJson: false,
  )
  final Map<String, dynamic> raw;

  /// Creates a [WingTransaction].
  const WingTransaction({
    required this.amount,
    required this.orderReferenceNo,
    required this.transactionId,
    this.totalAmount,
    this.currency,
    this.remark,
    this.customerName,
    this.fee,
    this.feeCurrency,
    this.wingAccount,
    this.psTrnId,
    this.fcTrnId,
    this.billerName,
    this.transactionDate,
    this.raw = const {},
  });

  /// Whether [amount] is at least [price], compared in cents.
  bool covers(num price) => (amount * 100).round() >= (price * 100).round();

  /// Parses Wing JSON.
  factory WingTransaction.fromJson(Map<String, dynamic> json) =>
      _$WingTransactionFromJson(json);

  /// Wing's JSON form of the modelled fields.
  Map<String, dynamic> toJson() => _$WingTransactionToJson(this);

  static Object? _wholeObject(Map<dynamic, dynamic> json, String key) => json;

  static Map<String, dynamic> _rawFromJson(Object? json) =>
      Map.unmodifiable(json as Map<String, dynamic>);

  @override
  String toString() =>
      'WingTransaction(transactionId: $transactionId, '
      'orderReferenceNo: $orderReferenceNo, amount: $amount $currency)';
}
