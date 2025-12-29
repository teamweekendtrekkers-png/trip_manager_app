import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build a simple app and trigger a frame
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Trip Manager'),
          ),
        ),
      ),
    );

    expect(find.text('Trip Manager'), findsOneWidget);
  });
}
