// The whole checkout with a fake backend and no web view: every outcome of
// a Wing payment, offline.
import 'package:example/main.dart';
import 'package:example/src/checkout_page.dart';
import 'package:example/src/payment_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_wing_checkout/flutter_wing_checkout.dart';

class FakeBackend implements PaymentBackend {
  FakeBackend({this.inquiry, this.authorizeError});

  final Map<String, dynamic>? inquiry;
  final String? authorizeError;
  final created = <(num, String)>[];
  int confirms = 0;

  @override
  Future<CheckoutSession> createCheckout({
    required num amount,
    required String itemName,
  }) async {
    if (authorizeError != null) throw PaymentException(authorizeError!);
    created.add((amount, itemName));
    return CheckoutSession(
      orderReferenceNo: 'order-1',
      amount: amount,
      confirmUrl: Uri.parse('https://wing.test/confirm?token=t'),
      returnUrl: 'https://shop.test/wing/return',
      cancelUrl: 'https://shop.test/wing/cancel',
    );
  }

  @override
  Future<WingInquiryResponse> confirm(CheckoutSession session) async {
    confirms++;
    return WingInquiryResponse.fromJson(
      inquiry ??
          {'errorCode': 'PG-I007', 'errorText': 'Reference number not found'},
    );
  }
}

OpenCheckout redirectTo(String url) =>
    (context, session) async => WingCheckoutResult.match(
      Uri.parse(url),
      returnUrl: Uri.parse(session.returnUrl),
      cancelUrl: Uri.parse(session.cancelUrl),
    );

const paid = {
  'errorCode': '200',
  'amount': '2.70',
  'currency': 'USD',
  'order_reference_no': 'order-1',
  'transaction_id': 'WING-TRN-1',
};

Future<void> pay(WidgetTester tester) async {
  await tester.tap(find.text('Pay with Wing'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('without a .env, the setup instructions show', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.text('Wing credentials needed'), findsOneWidget);
    expect(find.textContaining('--dart-define-from-file=.env'), findsOneWidget);
  });

  testWidgets('a paid order is confirmed and shows the receipt', (
    tester,
  ) async {
    final backend = FakeBackend(inquiry: paid);
    await tester.pumpWidget(
      ExampleApp(
        backend: backend,
        openCheckout: redirectTo(
          'https://shop.test/wing/return?status=success&token=t',
        ),
      ),
    );
    expect(find.text('\$2.70'), findsOneWidget);

    await pay(tester);

    expect(backend.created.single, (2.7, '1 x Iced coffee, 1 x Croissant'));
    expect(backend.confirms, 1);
    expect(find.text('Payment confirmed'), findsOneWidget);
    expect(find.text('WING-TRN-1'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Checkout'), findsOneWidget);
  });

  testWidgets('the cart total follows the quantities', (tester) async {
    final backend = FakeBackend(inquiry: paid);
    await tester.pumpWidget(ExampleApp(backend: backend));
    await tester.tap(find.byTooltip('Add Iced coffee'));
    await tester.tap(find.byTooltip('Remove Croissant'));
    await tester.pump();
    expect(find.text('\$3.00'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove Iced coffee'));
    await tester.tap(find.byTooltip('Remove Iced coffee'));
    await tester.pump();
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Pay with Wing'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNull, reason: 'nothing to pay');
  });

  testWidgets('a cancelled payment can be checked later', (tester) async {
    final backend = FakeBackend();
    await tester.pumpWidget(
      ExampleApp(
        backend: backend,
        openCheckout: redirectTo('https://shop.test/wing/cancel'),
      ),
    );
    await pay(tester);
    expect(find.textContaining('Payment cancelled'), findsOneWidget);
    expect(backend.confirms, 0);

    await tester.tap(find.text('Check order order-1'));
    await tester.pumpAndSettle();
    expect(backend.confirms, 1);
    expect(find.textContaining('PG-I007'), findsOneWidget);
  });

  testWidgets('a failed payment is reported', (tester) async {
    await tester.pumpWidget(
      ExampleApp(
        backend: FakeBackend(),
        openCheckout: redirectTo('https://shop.test/wing/return?status=fail'),
      ),
    );
    await pay(tester);
    expect(find.text('Wing reports the payment failed.'), findsOneWidget);
  });

  testWidgets('an amount below the price is not accepted', (tester) async {
    await tester.pumpWidget(
      ExampleApp(
        backend: FakeBackend(inquiry: {...paid, 'amount': '1.00'}),
        openCheckout: redirectTo(
          'https://shop.test/wing/return?status=success&token=t',
        ),
      ),
    );
    await pay(tester);
    expect(find.textContaining('not accepted'), findsOneWidget);
    expect(find.text('Payment confirmed'), findsNothing);
  });

  testWidgets('an authorization error is shown', (tester) async {
    await tester.pumpWidget(
      ExampleApp(
        backend: FakeBackend(authorizeError: 'Wing refused the payment: 401'),
      ),
    );
    await pay(tester);
    expect(find.text('Wing refused the payment: 401'), findsOneWidget);
  });
}
