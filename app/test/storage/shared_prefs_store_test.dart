import 'package:flutter_test/flutter_test.dart';
import 'package:herald/storage/key_value_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('values written through SharedPrefsStore are read back', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPrefsStore(await SharedPreferences.getInstance());

    expect(await store.getBool('flag'), isNull);
    expect(await store.getString('name'), isNull);

    await store.setBool('flag', true);
    await store.setString('name', 'light');

    expect(await store.getBool('flag'), isTrue);
    expect(await store.getString('name'), 'light');
  });

  test('a value saved earlier is still there in a new store', () async {
    SharedPreferences.setMockInitialValues({'flag': false});
    final store = SharedPrefsStore(await SharedPreferences.getInstance());

    expect(await store.getBool('flag'), isFalse);
  });
}
