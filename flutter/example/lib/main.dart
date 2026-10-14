import 'package:flutter/material.dart';
import 'package:flutter_wing/flutter_wing.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'flutter_wing',
    theme: ThemeData(colorSchemeSeed: Colors.lightGreen),
    home: const CheckoutPage(),
  );
}

const returnUrl = 'https://your-domain.com/wing/return';
const cancelUrl = 'https://your-domain.com/wing/cancel';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  String _message = 'Total \$6.00';

  /// Your server authorizes the payment with dart_wing (or the PHP, Kotlin
  /// or Node.js SDK) and returns `confirmUrl`; the secrets stay there.
  Future<Uri> _authorizeOnServer() async => throw UnimplementedError(
    'call your server, which returns WingAuthorizationResponse.confirmUrl',
  );

  Future<void> _pay() async {
    final Uri confirmUrl;
    try {
      confirmUrl = await _authorizeOnServer();
    } on UnimplementedError catch (e) {
      setState(() => _message = '${e.message}');
      return;
    }
    if (!mounted) return;
    final result = await WingCheckoutView.open(
      context,
      confirmUrl: confirmUrl,
      returnUrl: returnUrl,
      cancelUrl: cancelUrl,
    );
    setState(
      () => _message = switch (result?.status) {
        // confirm with WingService.inquiry on your server before delivering
        WingCheckoutStatus.success => 'Paid, confirming…',
        WingCheckoutStatus.failed => 'Payment failed',
        WingCheckoutStatus.cancelled || null => 'Payment cancelled',
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Checkout')),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: _pay, child: const Text('Pay with Wing')),
        ],
      ),
    ),
  );
}
