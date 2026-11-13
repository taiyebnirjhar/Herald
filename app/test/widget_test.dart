import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:herald/main.dart';

void main() {
  testWidgets('Hello screen shows the Herald greeting', (tester) async {
    await tester.pumpWidget(const HeraldApp());

    expect(find.text('Hello, Herald'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('Continue shows a confirmation message', (tester) async {
    await tester.pumpWidget(const HeraldApp());

    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(find.text('Hello from Herald. The app runs.'), findsOneWidget);
  });
}
