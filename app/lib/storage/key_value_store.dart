import 'package:shared_preferences/shared_preferences.dart';

/// The small amount of state Herald keeps on the phone: the welcome flag and
/// the settings. Code depends on this interface, so tests can use a fake.
abstract class KeyValueStore {
  Future<bool?> getBool(String key);
  Future<void> setBool(String key, bool value);
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
}

/// The real store, kept in shared_preferences on the phone.
class SharedPrefsStore implements KeyValueStore {
  SharedPrefsStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<bool?> getBool(String key) async => _prefs.getBool(key);

  @override
  Future<void> setBool(String key, bool value) async {
    await _prefs.setBool(key, value);
  }

  @override
  Future<String?> getString(String key) async => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }
}
