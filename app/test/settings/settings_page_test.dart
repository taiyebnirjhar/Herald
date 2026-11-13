import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:herald/main.dart';
import 'package:herald/runtime/hermes_pin.dart';
import 'package:herald/settings/app_settings.dart';
import 'package:herald/settings/settings_page.dart';

import '../support/fake_installer.dart';
import '../support/fake_key_value_store.dart';

Future<void> _openSettings(
  WidgetTester tester, {
  required FakeKeyValueStore store,
  FakeInstaller? installer,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: SettingsPage(
        settings: AppSettings(store),
        installer: installer ?? FakeInstaller(versionName: '0.1.3'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

bool _switchValue(WidgetTester tester, String title) => tester
    .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, title))
    .value;

/// A test on a phone-sized screen (412 x 915 logical pixels).
void phoneTest(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(412, 1400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await body(tester);
  });
}

void main() {
  phoneTest('shows the defaults and the light-only note', (tester) async {
    await _openSettings(tester, store: FakeKeyValueStore());

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Follow the phone'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.textContaining('Herald looks light for now'), findsOneWidget);
    expect(_switchValue(tester, 'Wi-Fi only'), isTrue);
    expect(_switchValue(tester, 'Start after the phone restarts'), isTrue);
  });

  phoneTest('choosing Dark saves it', (tester) async {
    final store = FakeKeyValueStore();
    await _openSettings(tester, store: store);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(store.values[AppSettings.themeKey], 'dark');
    expect(await AppSettings(store).theme(), ThemeChoice.dark);
  });

  phoneTest('switching Wi-Fi only off saves it', (tester) async {
    final store = FakeKeyValueStore();
    await _openSettings(tester, store: store);

    await tester.tap(find.widgetWithText(SwitchListTile, 'Wi-Fi only'));
    await tester.pumpAndSettle();

    expect(_switchValue(tester, 'Wi-Fi only'), isFalse);
    expect(await AppSettings(store).wifiOnly(), isFalse);
  });

  phoneTest('switching start on boot off saves it', (tester) async {
    final store = FakeKeyValueStore();
    await _openSettings(tester, store: store);

    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Start after the phone restarts'),
    );
    await tester.pumpAndSettle();

    expect(await AppSettings(store).bootStart(), isFalse);
  });

  phoneTest('saved values are shown when the page opens', (tester) async {
    await _openSettings(
      tester,
      store: FakeKeyValueStore({
        AppSettings.themeKey: 'light',
        AppSettings.wifiOnlyKey: false,
      }),
    );

    expect(
      tester
          .widget<RadioGroup<ThemeChoice>>(find.byType(RadioGroup<ThemeChoice>))
          .groupValue,
      ThemeChoice.light,
    );
    expect(_switchValue(tester, 'Wi-Fi only'), isFalse);
  });

  phoneTest('About shows the app version and the Hermes pin', (tester) async {
    await _openSettings(tester, store: FakeKeyValueStore());

    expect(find.text('0.1.3'), findsOneWidget);
    expect(find.text(HermesPin.commit.substring(0, 12)), findsOneWidget);
    expect(find.text('Open-source licences'), findsOneWidget);
  });

  phoneTest('falls back to the constant version when Android gives none', (
    tester,
  ) async {
    await _openSettings(
      tester,
      store: FakeKeyValueStore(),
      installer: FakeInstaller(throwOnVersion: true),
    );

    expect(find.text(SettingsPage.fallbackVersion), findsOneWidget);
  });

  phoneTest('the licences entry opens the licences page', (tester) async {
    // Taller screen: the Settings list has more sections now, and the entry is at the bottom.
    tester.view.physicalSize = const Size(412, 2400);
    await _openSettings(tester, store: FakeKeyValueStore());

    await tester.tap(find.text('Open-source licences'));
    // Let the new page build and its texts start loading.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(LicensePage), findsOneWidget);
  });

  phoneTest('the settings icon on the home screen opens Settings', (
    tester,
  ) async {
    await tester.pumpWidget(
      HeraldApp(updates: fakeUpdates(), store: FakeKeyValueStore()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Wi-Fi only'), findsOneWidget);
    expect(find.text('Open-source licences'), findsOneWidget);
  });
}
