// Live tests on a device or the macOS desktop: they authorize payments with
// the Wing credentials of .env and open Wing's real payment page. Skipped
// without a .env:
//
//   flutter test integration_test -d macos --dart-define-from-file=.env
//
// Demo only: the credentials are compiled into the test app.
import 'package:example/main.dart';
import 'package:example/src/payment_backend.dart';
import 'package:example/src/wing_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_wing_checkout/flutter_wing_checkout.dart';
import 'package:integration_test/integration_test.dart';

/// Pumps until [finder] matches nothing, for at most [seconds].
Future<void> pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  int seconds = 30,
}) async {
  for (var i = 0; i < seconds * 2 && finder.evaluate().isNotEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final skip = WingConfig.missing.isNotEmpty;

  testWidgets('Wing payment page opens in WingCheckoutView', skip: skip, (
    tester,
  ) async {
    final wing = WingService(merchant: WingConfig.merchant());
    final returnUrl = '${WingConfig.referer}/wing/return';
    final cancelUrl = '${WingConfig.referer}/wing/cancel';
    final auth = await tester.runAsync(
      () => wing.authorize(
        WingPayment(
          orderReferenceNo: 'flutter${DateTime.now().millisecondsSinceEpoch}',
          amount: 0.1,
          returnUrl: returnUrl,
          cancelUrl: cancelUrl,
          itemName: 'flutter_wing_checkout integration test',
        ),
      ),
    );
    debugPrint('authorize: ${auth!.status.code} ${auth.status.message}');
    expect(auth.isSuccess, true, reason: '${auth.status}');

    InAppWebViewController? controller;
    final results = <WingCheckoutResult>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WingCheckoutView(
            confirmUrl: auth.confirmUrl!,
            returnUrl: returnUrl,
            cancelUrl: cancelUrl,
            onResult: results.add,
            onWebViewCreated: (c) => controller = c,
          ),
        ),
      ),
    );

    // the progress indicator disappears once the page has loaded
    await pumpUntilGone(tester, find.byType(CircularProgressIndicator));
    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: 'the page did not finish loading in 30 s',
    );

    final url = await tester.runAsync(() => controller!.getUrl());
    final text = await tester.runAsync(
      () => controller!.evaluateJavascript(source: 'document.body.innerText'),
    );
    debugPrint('loaded: ${url?.path}');
    debugPrint('page text: ${'$text'.replaceAll(RegExp(r'\s+'), ' ')}');
    expect(url?.host, auth.confirmUrl!.host);
    expect(results, isEmpty, reason: 'no redirect without paying');
  });

  testWidgets('the example app authorizes and opens Wing', skip: skip, (
    tester,
  ) async {
    await tester.pumpWidget(
      ExampleApp(backend: DemoPaymentBackend(WingConfig.merchant())),
    );
    await tester.tap(find.text('Pay with Wing'));
    // authorization is a real network call
    for (
      var i = 0;
      i < 60 && find.byType(WingCheckoutView).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 250)),
      );
      await tester.pump();
    }
    expect(
      find.byType(WingCheckoutView),
      findsOneWidget,
      reason:
          'authorization failed: ${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).join(' | ')}',
    );
    expect(find.widgetWithText(AppBar, 'Pay with Wing'), findsOneWidget);
  });
}
