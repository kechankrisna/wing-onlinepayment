import 'package:flutter/material.dart';
import 'package:flutter_wing/flutter_wing.dart';

import 'payment_backend.dart';
import 'receipt_page.dart';

/// Opens Wing's payment page and completes with how it ended; replaceable in
/// tests, where no web view exists.
typedef OpenCheckout =
    Future<WingCheckoutResult?> Function(
      BuildContext context,
      CheckoutSession session,
    );

Future<WingCheckoutResult?> _openWingCheckout(
  BuildContext context,
  CheckoutSession session,
) => WingCheckoutView.open(
  context,
  confirmUrl: session.confirmUrl,
  returnUrl: session.returnUrl,
  cancelUrl: session.cancelUrl,
  title: const Text('Pay with Wing'),
);

class Product {
  const Product(this.name, this.cents);

  final String name;
  final int cents;
}

const products = [Product('Iced coffee', 150), Product('Croissant', 120)];

String _usd(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';

/// A cart paid with Wing: authorize, pay on Wing's page, confirm, receipt.
class CheckoutPage extends StatefulWidget {
  const CheckoutPage({
    super.key,
    required this.backend,
    this.openCheckout = _openWingCheckout,
  });

  final PaymentBackend backend;
  final OpenCheckout openCheckout;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _quantities = {for (final p in products) p.name: 1};
  bool _busy = false;
  String? _message;
  CheckoutSession? _lastSession;

  int get _totalCents =>
      products.fold(0, (sum, p) => sum + p.cents * _quantities[p.name]!);

  String get _itemName => [
    for (final p in products)
      if (_quantities[p.name]! > 0) '${_quantities[p.name]} x ${p.name}',
  ].join(', ');

  Future<void> _run(Future<void> Function() step) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await step();
    } on PaymentException catch (e) {
      _show(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _show(String message) {
    if (mounted) setState(() => _message = message);
  }

  Future<void> _pay() => _run(() async {
    final session = await widget.backend.createCheckout(
      amount: _totalCents / 100,
      itemName: _itemName,
    );
    _lastSession = session;
    if (!mounted) return;
    final result = await widget.openCheckout(context, session);
    switch (result?.status) {
      case WingCheckoutStatus.success:
        await _confirm(session);
      case WingCheckoutStatus.failed:
        _show('Wing reports the payment failed.');
      case WingCheckoutStatus.cancelled || null:
        _show(
          'Payment cancelled. Order ${session.orderReferenceNo} is unpaid.',
        );
    }
  });

  /// A redirect is not a proof of payment: ask Wing, and check the amount.
  Future<void> _confirm(CheckoutSession session) async {
    final inquiry = await widget.backend.confirm(session);
    if (!mounted) return;
    if (inquiry.isPaid(session.amount)) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              ReceiptPage(session: session, transaction: inquiry.transaction!),
        ),
      );
      setState(() => _lastSession = null);
    } else if (inquiry.isSuccess) {
      _show(
        'Wing received ${inquiry.transaction!.amount}, '
        'less than ${session.amount}: not accepted.',
      );
    } else {
      _show(
        'Order ${session.orderReferenceNo} is not paid '
        '(${inquiry.status.code} ${inquiry.status.message}).',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = _lastSession;
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final p in products)
            ListTile(
              title: Text(p.name),
              subtitle: Text(_usd(p.cents)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Remove ${p.name}',
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _busy || _quantities[p.name] == 0
                        ? null
                        : () => setState(
                            () =>
                                _quantities[p.name] = _quantities[p.name]! - 1,
                          ),
                  ),
                  Text('${_quantities[p.name]}'),
                  IconButton(
                    tooltip: 'Add ${p.name}',
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _busy
                        ? null
                        : () => setState(
                            () =>
                                _quantities[p.name] = _quantities[p.name]! + 1,
                          ),
                  ),
                ],
              ),
            ),
          const Divider(),
          ListTile(
            title: Text('Total', style: theme.textTheme.titleMedium),
            trailing: Text(
              _usd(_totalCents),
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.account_balance_wallet_outlined),
            label: const Text('Pay with Wing'),
            onPressed: _busy || _totalCents == 0 ? null : _pay,
          ),
          if (last != null)
            TextButton(
              onPressed: _busy ? null : () => _run(() => _confirm(last)),
              child: Text('Check order ${last.orderReferenceNo}'),
            ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _message!,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}
