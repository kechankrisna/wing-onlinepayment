// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wing_status.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WingStatus _$WingStatusFromJson(Map<String, dynamic> json) => WingStatus(
  code: stringFromJson(json['errorCode']),
  message: stringFromJson(json['errorText']),
);

Map<String, dynamic> _$WingStatusToJson(WingStatus instance) =>
    <String, dynamic>{
      'errorCode': instance.code,
      'errorText': instance.message,
    };
