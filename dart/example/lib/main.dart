// Demo only: this app embeds the Wing REST API key and password to call the
// UAT environment directly. In production, call Wing from your server and
// never ship these secrets inside an app.
//
// Run with the package's UAT .env:
//   flutter run --dart-define-from-file=../.env
import 'package:dart_wing/dart_wing.dart';
import 'package:flutter/material.dart';

void main() => runApp(const WingDemoApp());

// values from --dart-define-from-file; empty when not provided
const _apiUrl = String.fromEnvironment('WING_API_URL');
const _username = String.fromEnvironment('WING_USERNAME');
const _restApiKey = String.fromEnvironment('WING_REST_API_KEY');
const _password = String.fromEnvironment('WING_PASSWORD');
const _billTillNumber = String.fromEnvironment('WING_BILL_TILL_NUMBER');
const _referer = String.fromEnvironment('WING_REFERER_DOMAIN');

/// Demo of the dart_wing SDK.
class WingDemoApp extends StatelessWidget {
  /// Creates the demo app.
  const WingDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wing Online Payment Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightGreen),
        useMaterial3: true,
      ),
      home: const WingDemoPage(),
    );
  }
}

/// Buttons calling each API and a log of the results.
class WingDemoPage extends StatefulWidget {
  /// Creates the demo page.
  const WingDemoPage({super.key});

  @override
  State<WingDemoPage> createState() => _WingDemoPageState();
}

class _WingDemoPageState extends State<WingDemoPage> {
  final wing = WingService(
    merchant: WingMerchant(
      username: _username,
      restApiKey: _restApiKey,
      password: _password,
      billTillNumber: _billTillNumber,
      referer: _referer,
      baseApiUrl: _apiUrl.isEmpty ? WingMerchant.uatBaseUrl : _apiUrl,
    ),
  );
  final log = <String>[];
  String? lastOrder;

  Future<void> run(String label, Future<String> Function() action) async {
    setState(() => log.insert(0, '$label…'));
    String result;
    try {
      result = await action();
    } on WingException catch (e) {
      result = '$e';
    }
    setState(() => log[0] = '$label: $result');
  }

  Future<String> authorize() async {
    final order = 'demo${DateTime.now().millisecondsSinceEpoch}';
    final response = await wing.authorize(
      WingPayment(
        orderReferenceNo: order,
        amount: 0.1,
        returnUrl: '$_referer/wing/return',
        cancelUrl: '$_referer/wing/cancel',
        itemName: 'Coffee',
      ),
    );
    if (response.isSuccess) lastOrder = order;
    // open response.confirmUrl in a browser or web view to pay
    return response.isSuccess
        ? '${response.confirmUrl}'
        : '${response.status.code} ${response.status.message}';
  }

  Future<String> inquiry() async {
    final order = lastOrder;
    if (order == null) return 'authorize a payment first';
    final response = await wing.inquiry(orderReferenceNo: order);
    return response.isSuccess
        ? 'paid ${response.transaction?.amount} '
              '(${response.transaction?.transactionId})'
        : '${response.status.code} ${response.status.message}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wing Online Payment Demo')),
      body: Column(
        children: [
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: () => run('authorize', authorize),
                child: const Text('authorize'),
              ),
              OutlinedButton(
                onPressed: () => run('inquiry', inquiry),
                child: const Text('inquiry'),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [for (final line in log) SelectableText(line)],
            ),
          ),
        ],
      ),
    );
  }
}
