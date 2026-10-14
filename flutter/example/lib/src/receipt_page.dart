import 'package:flutter/material.dart';
import 'package:flutter_wing/flutter_wing.dart';

import 'payment_backend.dart';

/// The confirmed payment. Wing asks partners to show its transaction id.
class ReceiptPage extends StatelessWidget {
  const ReceiptPage({
    super.key,
    required this.session,
    required this.transaction,
  });

  final CheckoutSession session;
  final WingTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <(String, String)>[
      ('Order', session.orderReferenceNo),
      ('Wing transaction', transaction.transactionId),
      (
        'Amount',
        '${transaction.amount.toStringAsFixed(2)} '
            '${transaction.currency ?? ''}',
      ),
      if (transaction.totalAmount != null)
        ('Total charged', transaction.totalAmount!.toStringAsFixed(2)),
      if (transaction.transactionDate != null)
        ('Date', transaction.transactionDate!),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.check_circle, size: 72, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            'Payment confirmed',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          for (final (label, value) in rows)
            ListTile(title: Text(label), trailing: SelectableText(value)),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
