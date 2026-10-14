/// Where Wing sends the payer after paying (`integration_type`).
enum WingIntegrationType {
  /// back to `return_url` in the browser (Wing's default)
  webApp('WEBAPP'),

  /// back into your app through the deep link you registered with Wing
  mobileApp('MOBAPP');

  const WingIntegrationType(this.value);

  /// the value sent to Wing
  final String value;
}
