import '../storage/key_value_store.dart';

/// Theme choice. Stored only: Herald looks light for now (WBS 5.6).
enum ThemeChoice { system, light, dark }

/// The settings page's values, kept in the key-value store (WBS 5.6).
/// Defaults: system theme, Wi-Fi only on, start on boot on.
class AppSettings {
  AppSettings(this._store);

  static const themeKey = 'herald.settings.theme';
  static const wifiOnlyKey = 'herald.settings.wifi_only';
  static const bootStartKey = 'herald.settings.boot_start';

  final KeyValueStore _store;

  Future<ThemeChoice> theme() async {
    final name = await _store.getString(themeKey);
    for (final choice in ThemeChoice.values) {
      if (choice.name == name) return choice;
    }
    return ThemeChoice.system;
  }

  Future<void> setTheme(ThemeChoice choice) =>
      _store.setString(themeKey, choice.name);

  /// Setup and update downloads will read this in a later change. Stored only.
  Future<bool> wifiOnly() async => await _store.getBool(wifiOnlyKey) ?? true;

  Future<void> setWifiOnly(bool value) => _store.setBool(wifiOnlyKey, value);

  /// Read by BootReceiver.kt after a restart (WBS 4.5). Key and default must match.
  Future<bool> bootStart() async => await _store.getBool(bootStartKey) ?? true;

  Future<void> setBootStart(bool value) => _store.setBool(bootStartKey, value);
}
