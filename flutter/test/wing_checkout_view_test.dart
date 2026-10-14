import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_wing_checkout/flutter_wing_checkout.dart';

/// A web view platform that records the created web view and lets the test
/// simulate what the page does.
class FakeInAppWebViewPlatform extends InAppWebViewPlatform {
  FakeWebViewWidget? webView;

  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) => webView = FakeWebViewWidget(params);
}

class FakeController extends PlatformInAppWebViewController {
  FakeController()
    : super.implementation(
        const PlatformInAppWebViewControllerCreationParams(id: 0),
      );
}

class FakeWebViewWidget extends PlatformInAppWebViewWidget {
  FakeWebViewWidget(super.params) : super.implementation();

  late final InAppWebViewController controller =
      params.controllerFromPlatform!(FakeController())
          as InAppWebViewController;

  @override
  Widget build(BuildContext context) => const SizedBox.expand();

  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) =>
      params.controllerFromPlatform!(controller) as T;

  @override
  void dispose() {}

  /// what the view decides for a navigation to [url]
  Future<NavigationActionPolicy?> navigate(String url) async =>
      await params.shouldOverrideUrlLoading!(
        controller,
        NavigationAction(
          request: URLRequest(url: WebUri(url)),
          isForMainFrame: true,
        ),
      );

  void loadStop(String url) => params.onLoadStop!(controller, WebUri(url));

  void historyUpdate(String url) =>
      params.onUpdateVisitedHistory!(controller, WebUri(url), false);
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
    late FakeInAppWebViewPlatform platform;

    setUp(
      () =>
          InAppWebViewPlatform.instance = platform = FakeInAppWebViewPlatform(),
    );

    Future<List<WingCheckoutResult>> pumpView(
      WidgetTester tester, {
      void Function(InAppWebViewController)? onWebViewCreated,
    }) async {
      final results = <WingCheckoutResult>[];
      await tester.pumpWidget(
        MaterialApp(
          home: WingCheckoutView(
            confirmUrl: confirmUrl,
            returnUrl: returnUrl,
            cancelUrl: cancelUrl,
            onResult: results.add,
            onWebViewCreated: onWebViewCreated,
          ),
        ),
      );
      return results;
    }

    testWidgets('loads the payment page with JavaScript', (tester) async {
      await pumpView(tester);
      final params = platform.webView!.params;
      expect(params.initialUrlRequest?.url.toString(), confirmUrl.toString());
      expect(params.initialSettings?.javaScriptEnabled, true);
      expect(params.initialSettings?.useShouldOverrideUrlLoading, true);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      platform.webView!.loadStop(confirmUrl.toString());
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('Wing pages load; the return URL is reported once', (
      tester,
    ) async {
      final results = await pumpView(tester);
      final webView = platform.webView!;

      expect(
        await webView.navigate('https://sdk-uat.wingmoney.com/pay'),
        NavigationActionPolicy.ALLOW,
      );
      expect(results, isEmpty);

      const success =
          'https://shop.test/wing/return?order=1001&status=success&token=t';
      expect(await webView.navigate(success), NavigationActionPolicy.CANCEL);
      webView.historyUpdate(success);
      expect(results, [
        WingCheckoutResult(
          status: WingCheckoutStatus.success,
          uri: Uri.parse(success),
        ),
      ]);
    });

    testWidgets('a redirect seen only in the history is reported', (
      tester,
    ) async {
      final results = await pumpView(tester);
      platform.webView!.historyUpdate(cancelUrl);
      expect(results.single.status, WingCheckoutStatus.cancelled);
    });

    testWidgets('onWebViewCreated is passed to the web view', (tester) async {
      final created = <InAppWebViewController>[];
      await pumpView(tester, onWebViewCreated: created.add);
      platform.webView!.params.onWebViewCreated!(platform.webView!.controller);
      expect(created, hasLength(1));
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

      await platform.webView!.navigate(cancelUrl);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(WingCheckoutView), findsNothing);
      expect(result?.status, WingCheckoutStatus.cancelled);
    });
  });
}
