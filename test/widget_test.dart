import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app renders a basic welcome widget', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Difa+'),
          ),
        ),
      ),
    );

    expect(find.text('Difa+'), findsOneWidget);
  });
}
