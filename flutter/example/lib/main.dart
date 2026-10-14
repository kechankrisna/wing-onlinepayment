// Complete Wing checkout with flutter_wing. Configure it with a .env (copy
// .env.example) and run:
//
//   flutter run --dart-define-from-file=.env
//
// Demo only: DemoPaymentBackend calls Wing from the app with the .env
// secrets. In a real app, your server keeps them and authorizes payments;
// replace DemoPaymentBackend with calls to your server.
import 'package:flutter/material.dart';

import 'src/checkout_page.dart';
import 'src/payment_backend.dart';
import 'src/wing_config.dart';

void main() => runApp(
  ExampleApp(
    backend: WingConfig.missing.isEmpty
        ? DemoPaymentBackend(WingConfig.merchant())
        : null,
  ),
);

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key, this.backend, this.openCheckout});

  /// `null` when the .env is missing
  final PaymentBackend? backend;

  /// replaces Wing's web view in tests
  final OpenCheckout? openCheckout;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'flutter_wing',
    theme: ThemeData(colorSchemeSeed: Colors.lightGreen),
    home: switch ((backend, openCheckout)) {
      (null, _) => const SetupPage(),
      (final backend?, null) => CheckoutPage(backend: backend),
      (final backend?, final open?) => CheckoutPage(
        backend: backend,
        openCheckout: open,
      ),
    },
  );
}

/// Shown until the .env is configured.
class SetupPage extends StatelessWidget {
  const SetupPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Wing credentials needed')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Copy .env.example to .env, fill in your Wing UAT '
          'credentials, and run:',
        ),
        const SizedBox(height: 12),
        const SelectableText(
          'flutter run --dart-define-from-file=.env',
          style: TextStyle(fontFamily: 'monospace'),
        ),
        const SizedBox(height: 12),
        Text('Missing: ${WingConfig.missing.join(', ')}'),
      ],
    ),
  );
}
