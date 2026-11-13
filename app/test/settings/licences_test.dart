import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:herald/settings/licences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every licence file is bundled and has text', () async {
    for (final (_, asset) in heraldLicenceFiles) {
      final text = await rootBundle.loadString(asset);
      expect(text.trim(), isNotEmpty, reason: asset);
    }
  });

  test('the licence entries name Herald, proot and libtalloc', () {
    final packages = heraldLicenceFiles.map((e) => e.$1).join(' | ');
    expect(packages, contains('Herald'));
    expect(packages, contains('proot'));
    expect(packages, contains('libtalloc'));
  });
}
