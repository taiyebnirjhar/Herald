import 'package:flutter_test/flutter_test.dart';
import 'package:herald/welcome/welcome_store.dart';

import '../support/fake_key_value_store.dart';

void main() {
  test('the welcome is not seen on a fresh install', () async {
    final welcome = WelcomeStore(FakeKeyValueStore());

    expect(await welcome.isSeen(), isFalse);
  });

  test('markSeen saves the flag, so the welcome is not shown again', () async {
    final fake = FakeKeyValueStore();
    final welcome = WelcomeStore(fake);

    await welcome.markSeen();

    expect(await welcome.isSeen(), isTrue);
    expect(fake.values[WelcomeStore.seenKey], isTrue);
    // A new store over the same saved values also sees it.
    expect(await WelcomeStore(fake).isSeen(), isTrue);
  });
}
