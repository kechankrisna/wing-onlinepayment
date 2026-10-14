import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_wing/flutter_wing.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

/// A web view platform that records what is loaded and lets the test
/// simulate navigations.
class FakeWebViewPlatform extends WebViewPlatform {
  final controllers = <FakeController>[];
  FakeNavigationDelegate? delegate;

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    final controller = FakeController(params);
    controllers.add(controller);
    return controller;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => delegate = FakeNavigationDelegate(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => FakeWebViewWidget(params);
}

class FakeController extends PlatformWebViewController {
  FakeController(super.params) : super.implementation();

  final loaded = <Uri>[];
  JavaScriptMode? javaScriptMode;

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    loaded.add(params.uri);
  }

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {
    this.javaScriptMode = javaScriptMode;
  }

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}
}

class FakeNavigationDelegate extends PlatformNavigationDelegate {
  FakeNavigationDelegate(super.params) : super.implementation();

  NavigationRequestCallback? onNavigationRequest;
  UrlChangeCallback? onUrlChange;
  PageEventCallback? onPageFinished;

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback callback,
  ) async {
    onNavigationRequest = callback;
  }

  @override
  Future<void> setOnUrlChange(UrlChangeCallback callback) async {
    onUrlChange = callback;
  }

  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async {
    onPageFinished = callback;
  }

  @override
  Future<void> setOnPageStarted(PageEventCallback callback) async {}

  @override
  Future<void> setOnProgress(ProgressCallback callback) async {}

  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async {}

  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback callback) async {}

  @override
  Future<void> setOnHttpAuthRequest(HttpAuthRequestCallback callback) async {}

  @override
  Future<void> setOnSSlAuthError(SslAuthErrorCallback callback) async {}

  /// what the view decides for a navigation to [url]
  Future<NavigationDecision> navigate(String url) async =>
      await onNavigationRequest!(
        NavigationRequest(url: url, isMainFrame: true),
      );
}

class FakeWebViewWidget extends PlatformWebViewWidget {
  FakeWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

const returnUrl = 'https://shop.test/wing/return?order=1001';
const cancelUrl = 'https://shop.test/wing/cancel';
final confirmUrl = Uri.parse(
  'https://sdk-uat.wingmoney.com/wingonlinesdkv2/v1/online/payment/confirm?token=dG9rZW4%3D',
);

void main() {
  group('WingCheckoutResult.match', () {
    WingCheckoutResult? match(String url) => WingCheckoutResult.match(
      Uri.parse(url),
      returnUrl: Uri.parse(returnUrl),
      cancelUrl: Uri.parse(cancelUrl),
    );

    test('the return URL with status=success is a success', () {
      final result = match(
        'https://shop.test/wing/return?order=1001&status=success&token=f17a29f5',
      );
      expect(result?.status, WingCheckoutStatus.success);
      expect(result?.isSuccess, true);
      expect(result?.token, 'f17a29f5');
    });

    test('the return URL without status=success is a failure', () {
      expect(
        match('https://shop.test/wing/return/?order=1001&status=fail')?.status,
        WingCheckoutStatus.failed,
      );
    });

    test('the cancel URL is a cancellation', () {
      expect(
        match('https://shop.test/wing/cancel?x=1')?.status,
        WingCheckoutStatus.cancelled,
      );
    });

    test('other pages, or a missing query parameter, do not match', () {
      expect(match(confirmUrl.toString()), isNull);
      expect(match('https://shop.test/wing/return?status=success'), isNull);
      expect(
        match('https://shop.test/wing/return?order=1002&status=success'),
        isNull,
      );
      expect(match('http://shop.test/wing/cancel'), isNull);
      expect(match('https://evil.test/wing/cancel'), isNull);
    });
  });

  group('WingCheckoutView', () {
    late FakeWebViewPlatform platform;

    setUp(() => WebViewPlatform.instance = platform = FakeWebViewPlatform());

    Future<List<WingCheckoutResult>> pumpView(WidgetTester tester) async {
      final results = <WingCheckoutResult>[];
      await tester.pumpWidget(
        MaterialApp(
          home: WingCheckoutView(
            confirmUrl: confirmUrl,
            returnUrl: returnUrl,
            cancelUrl: cancelUrl,
            onResult: results.add,
          ),
        ),
      );
      return results;
    }

    testWidgets('loads the payment page with JavaScript', (tester) async {
      await pumpView(tester);
      final controller = platform.controllers.single;
      expect(controller.loaded, [confirmUrl]);
      expect(controller.javaScriptMode, JavaScriptMode.unrestricted);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      platform.delegate!.onPageFinished!(confirmUrl.toString());
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('Wing pages load; the return URL is reported once', (
      tester,
    ) async {
      final results = await pumpView(tester);
      final delegate = platform.delegate!;

      expect(
        await delegate.navigate('https://sdk-uat.wingmoney.com/pay'),
        NavigationDecision.navigate,
      );
      expect(results, isEmpty);

      const success =
          'https://shop.test/wing/return?order=1001&status=success&token=t';
      expect(await delegate.navigate(success), NavigationDecision.prevent);
      delegate.onUrlChange!(const UrlChange(url: success));
      expect(results, [
        WingCheckoutResult(
          status: WingCheckoutStatus.success,
          uri: Uri.parse(success),
        ),
      ]);
    });

    testWidgets('a redirect seen only as a URL change is reported', (
      tester,
    ) async {
      final results = await pumpView(tester);
      platform.delegate!.onUrlChange!(const UrlChange(url: cancelUrl));
      expect(results.single.status, WingCheckoutStatus.cancelled);
    });

    testWidgets('open() pops with the result', (tester) async {
      WingCheckoutResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await WingCheckoutView.open(
                  context,
                  confirmUrl: confirmUrl,
                  returnUrl: returnUrl,
                  cancelUrl: cancelUrl,
                );
              },
              child: const Text('pay'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('pay'));
      // the progress indicator never settles: pump past the route animation
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(WingCheckoutView), findsOneWidget);

      await platform.delegate!.navigate(cancelUrl);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(WingCheckoutView), findsNothing);
      expect(result?.status, WingCheckoutStatus.cancelled);
    });
  });
}
