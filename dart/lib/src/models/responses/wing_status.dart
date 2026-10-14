import 'package:json_annotation/json_annotation.dart';

import '../json_converters.dart';

part 'wing_status.g.dart';

/// `errorCode` and `errorText` of Wing responses. Success is `200`.
@JsonSerializable(includeIfNull: false)
class WingStatus {
  /// Wing's code, e.g. `200`, `401` (invalid REST API key), `006035`
  /// (transaction not found)
  @JsonKey(name: 'errorCode', fromJson: stringFromJson)
  final String code;

  /// human readable message
  @JsonKey(name: 'errorText', fromJson: stringFromJson)
  final String message;

  /// Creates a [WingStatus].
  const WingStatus({required this.code, required this.message});

  /// Whether Wing answered `200`.
  bool get isSuccess => code == '200';

  /// Parses Wing JSON.
  factory WingStatus.fromJson(Map<String, dynamic> json) =>
      _$WingStatusFromJson(json);

  /// Wing's JSON form.
  Map<String, dynamic> toJson() => _$WingStatusToJson(this);

  @override
  String toString() => 'WingStatus(code: $code, message: $message)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WingStatus && other.code == code && other.message == message;

  @override
  int get hashCode => Object.hash(code, message);
}
