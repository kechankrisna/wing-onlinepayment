import 'package:flutter/foundation.dart';

/// How a checkout on Wing's payment page ended.
enum WingCheckoutStatus {
  /// Wing redirected to the return URL with `status=success`; confirm with
  /// `WingService.inquiry` on your server before delivering
  success,

  /// Wing redirected to the return URL without `status=success`
  failed,

  /// the payer cancelled: Wing redirected to the cancel URL
  cancelled,
}

/// The redirect that ended a checkout.
@immutable
class WingCheckoutResult {
  /// Creates a result.
  const WingCheckoutResult({required this.status, required this.uri});

  /// how the checkout ended
  final WingCheckoutStatus status;

  /// the URL Wing redirected to
  final Uri uri;

  /// the `token` Wing appends to the return URL, if any
  String? get token => uri.queryParameters['token'];

  /// Whether Wing reported a successful payment. Not a proof of payment:
  /// confirm with `WingService.inquiry` on your server.
  bool get isSuccess => status == WingCheckoutStatus.success;

  /// The result of navigating to [uri], or `null` when [uri] is neither
  /// [returnUrl] nor [cancelUrl].
  ///
  /// A URL matches when its scheme, host, port and path are equal (ignoring
  /// a trailing `/`) and it carries every query parameter of the configured
  /// URL; Wing adds its own (`status`, `token`).
  static WingCheckoutResult? match(
    Uri uri, {
    required Uri returnUrl,
    required Uri cancelUrl,
  }) {
    if (_matches(uri, returnUrl)) {
      return WingCheckoutResult(
        status: uri.queryParameters['status'] == 'success'
            ? WingCheckoutStatus.success
            : WingCheckoutStatus.failed,
        uri: uri,
      );
    }
    if (_matches(uri, cancelUrl)) {
      return WingCheckoutResult(status: WingCheckoutStatus.cancelled, uri: uri);
    }
    return null;
  }

  static bool _matches(Uri uri, Uri configured) {
    String path(Uri u) =>
        u.path.endsWith('/') ? u.path.substring(0, u.path.length - 1) : u.path;
    if (uri.scheme != configured.scheme ||
        uri.host != configured.host ||
        uri.port != configured.port ||
        path(uri) != path(configured)) {
      return false;
    }
    final params = uri.queryParameters;
    return configured.queryParameters.entries.every(
      (e) => params[e.key] == e.value,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WingCheckoutResult && other.status == status && other.uri == uri;

  @override
  int get hashCode => Object.hash(status, uri);

  @override
  String toString() => 'WingCheckoutResult(${status.name}, $uri)';
}
