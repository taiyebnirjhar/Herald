import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:herald/main.dart';
import 'package:herald/setup/setup_page.dart';
import 'package:herald/welcome/welcome_flow.dart';
import 'package:herald/welcome/welcome_store.dart';

import '../support/fake_installer.dart';
import '../support/fake_key_value_store.dart';

/// A test on a phone-sized screen (412 x 915 logical pixels).
void phoneTest(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await body(tester);
  });
}

void main() {
  phoneTest(
    'three screens in order, then Go to Herald saves and opens home',
    (tester) async {
      final store = FakeKeyValueStore();
      await tester.pumpWidget(
        HeraldApp(updates: fakeUpdates(), store: store, showWelcome: true),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome to Herald'), findsOneWidget);
      expect(find.text('Hello, Herald'), findsNothing);
      expect(find.text('Next'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Set up once, over Wi-Fi'), findsOneWidget);
      expect(find.text('Open setup'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Two permissions'), findsOneWidget);
      expect(find.textContaining('allow installs from Herald'), findsOneWidget);
      expect(find.textContaining('Notifications'), findsOneWidget);

      await tester.tap(find.text('Go to Herald'));
      await tester.pumpAndSettle();

      expect(find.text('Hello, Herald'), findsOneWidget);
      expect(find.text('Welcome to Herald'), findsNothing);
      expect(await WelcomeStore(store).isSeen(), isTrue);
    },
  );

  phoneTest('Back goes to the previous screen', (tester) async {
    await tester.pumpWidget(
      HeraldApp(
        updates: fakeUpdates(),
        store: FakeKeyValueStore(),
        showWelcome: true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Set up once, over Wi-Fi'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Herald'), findsOneWidget);
  });

  phoneTest('the setup button opens the existing setup screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      HeraldApp(
        updates: fakeUpdates(),
        store: FakeKeyValueStore(),
        showWelcome: true,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open setup'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(SetupPage), findsOneWidget);
  });

  phoneTest('a store that cannot save still opens the home screen', (
    tester,
  ) async {
    final store = _BrokenStore();
    await tester.pumpWidget(
      HeraldApp(updates: fakeUpdates(), store: store, showWelcome: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Go to Herald'));
    await tester.pumpAndSettle();

    expect(find.text('Hello, Herald'), findsOneWidget);
  });

  phoneTest('WelcomeFlow can be used on its own', (tester) async {
    final store = FakeKeyValueStore();
    await tester.pumpWidget(
      MaterialApp(
        home: WelcomeFlow(
          welcome: WelcomeStore(store),
          homeBuilder: (_) => const Scaffold(body: Text('Home here')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Go to Herald'));
    await tester.pumpAndSettle();

    expect(find.text('Home here'), findsOneWidget);
    expect(store.values[WelcomeStore.seenKey], isTrue);
  });
}

/// A store whose saves always fail, to check the flow still gets the player home.
class _BrokenStore extends FakeKeyValueStore {
  @override
  Future<void> setBool(String key, bool value) async =>
      throw StateError('disk full');
}
