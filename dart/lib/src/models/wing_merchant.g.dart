// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wing_merchant.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WingMerchant _$WingMerchantFromJson(Map<String, dynamic> json) => WingMerchant(
  username: json['username'] as String,
  restApiKey: json['restApiKey'] as String,
  password: json['password'] as String,
  billTillNumber: json['billTillNumber'] as String,
  referer: json['referer'] as String,
  baseApiUrl: json['baseApiUrl'] as String? ?? WingMerchant.uatBaseUrl,
  sandbox: json['sandbox'] as bool? ?? true,
);

Map<String, dynamic> _$WingMerchantToJson(WingMerchant instance) =>
    <String, dynamic>{
      'username': instance.username,
      'restApiKey': instance.restApiKey,
      'password': instance.password,
      'billTillNumber': instance.billTillNumber,
      'referer': instance.referer,
      'baseApiUrl': instance.baseApiUrl,
      'sandbox': instance.sandbox,
    };
