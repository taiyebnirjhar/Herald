import 'package:herald/storage/key_value_store.dart';

/// An in-memory store for tests. Keeps values in a plain map.
class FakeKeyValueStore implements KeyValueStore {
  FakeKeyValueStore([Map<String, Object>? initial])
    : values = Map<String, Object>.of(initial ?? {});

  final Map<String, Object> values;

  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;

  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;

  @override
  Future<String?> getString(String key) async => values[key] as String?;

  @override
  Future<void> setString(String key, String value) async => values[key] = value;
}
