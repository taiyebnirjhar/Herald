import 'package:flutter_test/flutter_test.dart';
import 'package:herald/settings/app_settings.dart';

import '../support/fake_key_value_store.dart';

void main() {
  test('defaults: system theme, Wi-Fi only on, start on boot on', () async {
    final settings = AppSettings(FakeKeyValueStore());

    expect(await settings.theme(), ThemeChoice.system);
    expect(await settings.wifiOnly(), isTrue);
    expect(await settings.bootStart(), isTrue);
  });

  test('each setting is saved and read back', () async {
    final fake = FakeKeyValueStore();
    final settings = AppSettings(fake);

    await settings.setTheme(ThemeChoice.dark);
    await settings.setWifiOnly(false);
    await settings.setBootStart(false);

    expect(await settings.theme(), ThemeChoice.dark);
    expect(await settings.wifiOnly(), isFalse);
    expect(await settings.bootStart(), isFalse);
    // Read again through a new object over the same store.
    final again = AppSettings(fake);
    expect(await again.theme(), ThemeChoice.dark);
    expect(await again.wifiOnly(), isFalse);
    expect(await again.bootStart(), isFalse);
  });

  test('light is saved and read back, not just dark', () async {
    final settings = AppSettings(FakeKeyValueStore());

    await settings.setTheme(ThemeChoice.light);

    expect(await settings.theme(), ThemeChoice.light);
  });

  test('an unknown saved theme falls back to system', () async {
    final settings = AppSettings(
      FakeKeyValueStore({AppSettings.themeKey: 'purple'}),
    );

    expect(await settings.theme(), ThemeChoice.system);
  });
}
