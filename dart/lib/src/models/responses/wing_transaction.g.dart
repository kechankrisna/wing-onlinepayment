// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wing_transaction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WingTransaction _$WingTransactionFromJson(Map<String, dynamic> json) =>
    WingTransaction(
      amount: doubleFromJson(json['amount']),
      orderReferenceNo: stringFromJson(json['order_reference_no']),
      transactionId: stringFromJson(json['transaction_id']),
      totalAmount: nullableDoubleFromJson(json['total_amount']),
      currency: nullableStringFromJson(json['currency']),
      remark: nullableStringFromJson(json['remark']),
      customerName: nullableStringFromJson(json['customer_name']),
      fee: nullableDoubleFromJson(json['fee']),
      feeCurrency: nullableStringFromJson(json['fee_currency']),
      wingAccount: nullableStringFromJson(json['wing_account']),
      psTrnId: nullableStringFromJson(json['ps_trn_id']),
      fcTrnId: nullableStringFromJson(json['fc_trn_id']),
      billerName: nullableStringFromJson(json['biller_name']),
      transactionDate: nullableStringFromJson(json['transaction_date']),
      raw: WingTransaction._wholeObject(json, 'raw') == null
          ? const {}
          : WingTransaction._rawFromJson(
              WingTransaction._wholeObject(json, 'raw'),
            ),
    );

Map<String, dynamic> _$WingTransactionToJson(WingTransaction instance) =>
    <String, dynamic>{
      'amount': instance.amount,
      'total_amount': ?instance.totalAmount,
      'currency': ?instance.currency,
      'order_reference_no': instance.orderReferenceNo,
      'transaction_id': instance.transactionId,
      'remark': ?instance.remark,
      'customer_name': ?instance.customerName,
      'fee': ?instance.fee,
      'fee_currency': ?instance.feeCurrency,
      'wing_account': ?instance.wingAccount,
      'ps_trn_id': ?instance.psTrnId,
      'fc_trn_id': ?instance.fcTrnId,
      'biller_name': ?instance.billerName,
      'transaction_date': ?instance.transactionDate,
    };
