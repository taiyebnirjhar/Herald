import '../storage/key_value_store.dart';

/// Remembers whether the player has seen the welcome flow (WBS 5.1).
/// The flow is shown on first launch only.
class WelcomeStore {
  WelcomeStore(this._store);

  static const seenKey = 'herald.welcome.seen';

  final KeyValueStore _store;

  /// False until [markSeen] has been called and saved.
  Future<bool> isSeen() async => await _store.getBool(seenKey) ?? false;

  Future<void> markSeen() => _store.setBool(seenKey, true);
}
