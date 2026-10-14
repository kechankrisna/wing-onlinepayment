import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'wing_checkout_result.dart';

/// Wing's payment page in a web view. It reports how the checkout ended as
/// soon as Wing redirects to [returnUrl] or [cancelUrl], without loading
/// them.
///
/// Your server authorizes the payment with `dart_wing` (or another Wing SDK)
/// and returns `confirmUrl` to the app:
///
/// ```dart
/// final result = await WingCheckoutView.open(
///   context,
///   confirmUrl: confirmUrl,
///   returnUrl: 'https://your-domain.com/wing/return',
///   cancelUrl: 'https://your-domain.com/wing/cancel',
/// );
/// if (result?.isSuccess ?? false) {
///   // ask your server to confirm with WingService.inquiry
/// }
/// ```
///
/// Supported where `webview_flutter` is: Android, iOS and macOS.
class WingCheckoutView extends StatefulWidget {
  /// Creates the view.
  const WingCheckoutView({
    super.key,
    required this.confirmUrl,
    required this.returnUrl,
    required this.cancelUrl,
    required this.onResult,
    this.loading,
  });

  /// Wing's payment page, from `WingAuthorizationResponse.confirmUrl`
  final Uri confirmUrl;

  /// the `returnUrl` of the authorized `WingPayment`
  final String returnUrl;

  /// the `cancelUrl` of the authorized `WingPayment`
  final String cancelUrl;

  /// called once, when Wing redirects to [returnUrl] or [cancelUrl]
  final ValueChanged<WingCheckoutResult> onResult;

  /// shown until the first page has loaded; a progress indicator by default
  final Widget? loading;

  /// Pushes a page with a [WingCheckoutView] and completes with its result,
  /// or `null` when the payer leaves with the back button.
  static Future<WingCheckoutResult?> open(
    BuildContext context, {
    required Uri confirmUrl,
    required String returnUrl,
    required String cancelUrl,
    Widget title = const Text('Wing'),
  }) {
    return Navigator.of(context).push<WingCheckoutResult>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: title),
          body: WingCheckoutView(
            confirmUrl: confirmUrl,
            returnUrl: returnUrl,
            cancelUrl: cancelUrl,
            onResult: (result) => Navigator.of(context).pop(result),
          ),
        ),
      ),
    );
  }

  @override
  State<WingCheckoutView> createState() => _WingCheckoutViewState();
}

class _WingCheckoutViewState extends State<WingCheckoutView> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) => _finish(request.url)
              ? NavigationDecision.prevent
              : NavigationDecision.navigate,
          // redirects some platforms do not ask about
          onUrlChange: (change) {
            final url = change.url;
            if (url != null) _finish(url);
          },
          onPageFinished: (_) {
            if (mounted && _loading) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(widget.confirmUrl);
  }

  /// Reports the result when [url] is the return or cancel URL.
  bool _finish(String url) {
    final uri = Uri.tryParse(url);
    final returnUrl = Uri.tryParse(widget.returnUrl);
    final cancelUrl = Uri.tryParse(widget.cancelUrl);
    if (uri == null || returnUrl == null || cancelUrl == null) return false;
    final result = WingCheckoutResult.match(
      uri,
      returnUrl: returnUrl,
      cancelUrl: cancelUrl,
    );
    if (result == null) return false;
    if (!_done) {
      _done = true;
      widget.onResult(result);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_loading)
          Center(child: widget.loading ?? const CircularProgressIndicator()),
      ],
    );
  }
}
