// Smoke test of the demo screen. No network: the buttons are only rendered.
import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the demo actions', (WidgetTester tester) async {
    await tester.pumpWidget(const WingDemoApp());

    expect(find.text('Wing Online Payment Demo'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'authorize'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'inquiry'), findsOneWidget);
  });
}
