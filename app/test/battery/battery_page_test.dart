import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:herald/battery/battery_control.dart';
import 'package:herald/battery/battery_page.dart';

/// Stands in for Android. [exempt] changes to true when the player allows it.
class FakeBatteryControl implements BatteryControl {
  FakeBatteryControl({this.exempt = false, this.canOpen = true, this.canRequest = true});

  bool exempt;
  final bool canOpen;
  final bool canRequest;
  int requests = 0;
  int opens = 0;

  @override
  Future<bool> isExempt() async => exempt;

  @override
  Future<bool> requestExemption() async {
    requests++;
    if (canRequest) exempt = true;
    return canRequest;
  }

  @override
  Future<bool> openBatterySettings() async {
    opens++;
    return canOpen;
  }
}

Future<void> _open(WidgetTester tester, FakeBatteryControl control) async {
  await tester.pumpWidget(MaterialApp(home: BatteryPage(control: control)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows not allowed and an Allow button when Android may stop Herald', (tester) async {
    await _open(tester, FakeBatteryControl(exempt: false));

    expect(find.textContaining('Not allowed yet'), findsOneWidget);
    final allow = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Allow'));
    expect(allow.onPressed, isNotNull);
  });

  testWidgets('shows allowed and disables the button once Herald may run freely', (tester) async {
    await _open(tester, FakeBatteryControl(exempt: true));

    expect(find.textContaining('Allowed. Android will not stop Herald'), findsOneWidget);
    final done = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Allowed'));
    expect(done.onPressed, isNull);
  });

  testWidgets('Allow asks Android, then shows the new status', (tester) async {
    final control = FakeBatteryControl(exempt: false);
    await _open(tester, control);

    await tester.tap(find.widgetWithText(FilledButton, 'Allow'));
    await tester.pumpAndSettle();

    expect(control.requests, 1);
    expect(find.textContaining('Allowed. Android will not stop Herald'), findsOneWidget);
  });

  testWidgets('says so when this phone has no Android question to open', (tester) async {
    final control = FakeBatteryControl(exempt: false, canRequest: false);
    await _open(tester, control);

    await tester.tap(find.widgetWithText(FilledButton, 'Allow'));
    await tester.pumpAndSettle();

    expect(find.textContaining('did not open the Android question'), findsOneWidget);
    expect(find.textContaining('Not allowed yet'), findsOneWidget);
  });

  testWidgets('says so when no battery screen can be opened', (tester) async {
    final control = FakeBatteryControl(exempt: false, canOpen: false);
    await _open(tester, control);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Open battery settings'));
    await tester.pumpAndSettle();

    expect(control.opens, 1);
    expect(find.textContaining('did not open a battery screen'), findsOneWidget);
  });

  testWidgets('shows the Samsung steps in plain words', (tester) async {
    await _open(tester, FakeBatteryControl());

    expect(find.textContaining('Background usage limits'), findsOneWidget);
    expect(find.textContaining('Deep sleeping apps'), findsOneWidget);
  });
}
