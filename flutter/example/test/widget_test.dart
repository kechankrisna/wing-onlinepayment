import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('paying without a server explains what is missing', (
    tester,
  ) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.text('Total \$6.00'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Pay with Wing'));
    await tester.pump();
    expect(find.textContaining('call your server'), findsOneWidget);
  });
}
